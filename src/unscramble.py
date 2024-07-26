#!/usr/bin/env python3

import numpy as np

class Processor:
    def __init__(self, shift_delta, full_frame):
        self.shift = 0
        basic_cols = np.arange(8, dtype=int)
        offsets = (np.arange(64) * 32)[:,None]
        self.cols_in_row = (basic_cols + offsets).ravel()

        self.shift_delta = shift_delta
        self.full_frame = full_frame

    def reset_shift(self):
        self.shift = 0

    def ads_average(self, raw, *, ads_per_fowler=6, single_quad=False):
        block_size = 8 if single_quad else 32
        basic_cols = np.arange(block_size, dtype=int)
        offsets = (np.arange(64) * (block_size * ads_per_fowler))[:,None]
        cols_in_ads = (basic_cols + offsets).ravel()
        return np.mean([raw[:,:,cols_in_ads + (block_size * sample)] for sample in range(ads_per_fowler)], axis=0)

    def subtract(self, reset, signal, shift_resetted=True):
        """
        Subtracts reset data from signal data, shifting to correct the
        roll off effect as needed.

        Expected input are two datacubes of (nFS, nRows, nCols), where nFS
        is the number of fowler samples at each side of the exposure.

        The user can specify whether the roll off resets during the exposure
        or not. The need to shift will be determined automatically using the
        internal "shift_delta" argument.
        """
        # Frames at each side of the exposure
        subtracted = np.empty(reset.shape, dtype=reset.dtype)
        if self.shift_delta != 0:
            nframes = reset.shape[0]
            rshift = 0
            sshift = 0 if shift_resetted else (self.shift_delta * nframes)
            for n, (sigFrame, resFrame) in enumerate(zip(signal, reset)):
                subtracted[n,:,:] = self.rolled(sigFrame, sshift) - self.rolled(resFrame, rshift)
                sshift += self.shift
                rshift += self.shift
        else:
            subtracted[:,:,:] = signal - reset

        return subtracted

    def rolled(self, array, shift):
        if shift == 0:
            return array
        return np.roll(array, shift)

    def unscramble(self, scrambled):
        if self.full_frame:
            res = self.single_full_frame(scrambled)
        else:
            res = self.single_1q(scrambled)

        self.shift += self.shift_delta

        return res

    def single_full_frame(self, scrambled):
        cir = self.cols_in_row
        frame = np.empty((1024, 1024), dtype=scrambled.dtype)

        frame[512:, :512] = np.flipud(scrambled[:,cir]) # 1st q
        frame[512:, 512:] = np.flip(scrambled[:,cir + 8]) # 2nd q
        frame[:512, :512] = scrambled[:,cir + 16] # 3nd q
        frame[:512, 512:] = scrambled[:,cir + 24][:,-1::-1] # 4nd q

        return frame

    def single_1q(self, scrambled):
        return np.roll(scrambled, shift=8 * self.shift, axis=1)
