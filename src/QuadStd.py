#---------------------------------------------------------------
#QuadStd.py
#
# Program creates an output file for the standard deviation in each
# quadrant of a 1024x1024 fits array.  This also prints out the amount
# of fowler and digital averages as ascertained in the fits header.  With
# this information, one can judge the readnoise present in the system.
#
# This program also has the ability to screen by doing sigma cuts.  It will
# only include data that isn't clipped by this.  Furthermore, the rejection
# percentage will be included in the output.
#
# Finally, a tif file will be generated giving a visual representation of
# the clipped pixels.  This is useful to find potential pick-up pattern noise
# that may be in the system.
#
# Notes:  Program has two options.  It can either take in a group of fits files
#         determined by the first and last fits file - it will take this as input
#         along with all fits files in between.
#         Or, it can simply do one fits file.
#         Also note, the sigma value is hard-coded, but can be easily changed.
#
# usage:  python ./QuadStd.py <first fits file location> <last fits file location>
#                      <Output file name>
#         python ./QuadStd.py <fits file> <Output file name>
#---------------------------------------------------------------


import os
import sys
from astropy.io import fits
import numpy as np
from PIL import Image, ImageDraw, ImageFont


# ------------------------------------------------------------
# Quadrant boundaries (x1, x2, y1, y2)
# Note: FITS indexing is [y, x]
# ------------------------------------------------------------

QUADS = {
    1: (0, 512, 0, 512),       #(50, 462, 50, 438),
    2: (512, 1024, 0, 512),    #(562, 974, 50, 438),
    3: (0, 512, 512, 1024),    #(50, 462, 586, 950),
    4: (512, 1024, 512, 1024), #(562, 974, 586, 950),
}

def create_rejection_map(data, reject_mask, fits_name, lnrs, ndavgs, qmean, qstd,
    sigma_used, output_dir=None):
    """
    Create a TIFF image marking rejected pixels in red and quadrant boxes in yellow,
    with quadrant labels Q1–Q4 added.
    """

    height, width = data.shape
    img = Image.new("RGB", (width, height), (255, 255, 255))
    pixels = img.load()

    # -------------------------------------------
    # Draw rejected pixels (red)
    # -------------------------------------------
    for y in range(height):
        for x in range(width):
            if reject_mask[y, x]:
                pixels[x, y] = (255, 0, 0)   # red

    draw = ImageDraw.Draw(img)
    try:
        font_large = ImageFont.truetype('arial.ttf', size=18)
    except (IOError, OSError):
        font_large = ImageFont.load_default()
    # -------------------------------------------
    # Draw quadrant boxes + labels (yellow)
    # -------------------------------------------
    for qnum, (x1, x2, y1, y2) in QUADS.items():

        # Draw bounding box
        box = [(x1, y1), (x2, y1), (x2, y2), (x1, y2), (x1, y1)]
        draw.line(box, fill=(255, 255, 0), width=2)

        # Label position: just inside the box
        label_x = x1 + 5
        label_y = y1 + 5



        # Q1 gets extra labels
        if qnum == 1:
            label_text = f"Q1  F{lnrs}  D{ndavgs}"
        else:
            label_text = f"Q{qnum}"

        # Draw quadrant label
        draw.text((label_x, label_y), label_text, fill=(0, 0, 255), font=font_large)

        #Add mean
        text2 = f"MEAN = {qmean[qnum]:.3f}"
        draw.text((label_x, label_y + 18), text2, fill=(0, 0, 255), font=font_large)

        #Add std
        text3 = f"STD = {qstd[qnum]:.3f}"
        draw.text((label_x, label_y + 36), text3, fill=(0, 0, 255), font=font_large)

        #Add sigma line clipping
        if sigma_used == 0:
            text4 = "CLIP = No clipping"
        else:
            text4 = f"CLIP = {sigma_used}σ"

        draw.text((label_x, label_y + 54), text4, fill=(0, 0, 255), font=font_large)

    # -------------------------------------------
    # Save output (or return image if no name given)
    # -------------------------------------------
    if fits_name is None:
        return img

    tif_name = f"reject-map_{fits_name}.tif"
    if output_dir:
        tif_path = os.path.join(output_dir, tif_name)
    else:
        tif_path = tif_name

    img.save(tif_path, compression=None)
    print(f"Rejection TIFF saved: {tif_path}")


def sigma_clip_mask(values, sigma):
    """
    Perform n-sigma clipping unless sigma == 0, which means no clipping.
    Returns:
        clipped_values
        rejected_percent
        reject_mask
    """

    sub = values
    flat = sub.flatten()
    flat = flat[np.isfinite(flat)]

    total = len(flat)
    if total == 0:
        return flat, 0.0, np.zeros_like(sub, dtype=bool)

    # ------------------------------------------
    # NO CLIPPING MODE
    # ------------------------------------------
    if sigma == 0:
        reject_mask = np.zeros_like(sub, dtype=bool)   # nobody rejected
        return flat, 0.0, reject_mask

    # ------------------------------------------
    # NORMAL SIGMA CLIPPING
    # ------------------------------------------
    mean = np.mean(flat)
    std = np.std(flat)

    low = mean - sigma * std
    high = mean + sigma * std

    keep = (sub >= low) & (sub <= high)
    reject_mask = ~keep

    clipped = sub[keep]
    rejected = np.count_nonzero(reject_mask)
    rejected_pct = (rejected / sub.size) * 100.0

    return clipped, rejected_pct, reject_mask

def compute_quadrant_stats(data, quad, sigma_used):
    x1, x2, y1, y2 = QUADS[quad]
    sub = data[y1:y2+1, x1:x2+1]

    clipped, rejected_percent, reject_mask = sigma_clip_mask(sub, sigma_used)

    if len(clipped) == 0:
        return (float("nan"), float("nan"), rejected_percent, reject_mask, (x1, x2, y1, y2))

    mean_val = np.mean(clipped)
    std_val = np.std(clipped)

    return (mean_val, std_val, rejected_percent, reject_mask, (x1, x2, y1, y2))


# ------------------------------------------------------------
# Helper: process exactly one FITS file
# ------------------------------------------------------------

def process_single_file(full_path, f_out):
    fname = os.path.basename(full_path)
    hdul = fits.open(full_path)

    # HEADER → HDU 0
    primary_header = hdul[0].header
    lnrs = primary_header.get("LNRS", "NA")
    ndavgs = primary_header.get("NDAVGS", "NA")

    # IMAGE DATA → HDU 1
    if len(hdul) < 2 or hdul[1].data is None:
        print(f"ERROR: {fname} has no data in HDU 1. Skipping.")
        hdul.close()
        return

    data = hdul[1].data
    hdul.close()

    # Compute quadrant stats
    qmean = {}
    qstd = {}
    rejpct = {}
    qmask = {}
    qbounds = {}

    #specify sigma used for clipping
    sigma_used=1.5

    for q in range(1, 5):
        qmean[q], qstd[q], rejpct[q], qmask[q], qbounds[q] = compute_quadrant_stats(data, q, sigma_used)

    reject_mask_full = np.zeros_like(data, dtype=bool)

    for q in range(1, 5):
        x1, x2, y1, y2 = qbounds[q]
        reject_mask_full[y1:y2+1, x1:x2+1] = qmask[q]

    base = os.path.basename(full_path)
    root, extension = os.path.splitext(base)

    create_rejection_map(data, reject_mask_full, root, lnrs, ndavgs, qmean, qstd, sigma_used)

    # Write output line
    f_out.write(
        f"{fname} {lnrs} {ndavgs} "
        f"{qmean[1]:.6f} {qstd[1]:.6f} {rejpct[1]:.2f} "
        f"{qmean[2]:.6f} {qstd[2]:.6f} {rejpct[2]:.2f} "
        f"{qmean[3]:.6f} {qstd[3]:.6f} {rejpct[3]:.2f} "
        f"{qmean[4]:.6f} {qstd[4]:.6f} {rejpct[4]:.2f}\n"
    )

    print(
        f"{fname}: Fowler={lnrs}, digiAVGs={ndavgs}, "
        f"Q1(mean={qmean[1]:.4f}, std={qstd[1]:.4f}, rej={rejpct[1]:.2f}% rejected), "
        f"Q2(mean={qmean[2]:.4f}, std={qstd[2]:.4f}, rej={rejpct[2]:.2f}% rejected), "
        f"Q3(mean={qmean[3]:.4f}, std={qstd[3]:.4f}, rej={rejpct[3]:.2f}% rejected), "
        f"Q4(mean={qmean[4]:.4f}, std={qstd[4]:.4f}, rej={rejpct[4]:.2f}% rejected)"
    )

# ------------------------------------------------------------
# Main: handles single-file or range-of-files
# ------------------------------------------------------------

def main(first_file, last_file, output_file):

    # Open output file (append if exists)
    mode = "a" if os.path.exists(output_file) else "w"
    f_out = open(output_file, mode)

    # --------------------------------------------------------
    # SINGLE-FILE MODE
    # --------------------------------------------------------
    if last_file is None:
        print("\nProcessing 1 FITS file...\n")
        process_single_file(first_file, f_out)
        f_out.close()
        print(f"\nOutput saved to: {output_file}\n")
        return

    # --------------------------------------------------------
    # RANGE MODE
    # --------------------------------------------------------
    directory = os.path.dirname(first_file)
    first_name = os.path.basename(first_file)
    last_name = os.path.basename(last_file)

    fits_files = sorted([f for f in os.listdir(directory) if f.lower().endswith(".fits")])

    if first_name not in fits_files:
        print(f"ERROR: First file '{first_name}' not found in directory.")
        sys.exit(1)
    if last_name not in fits_files:
        print(f"ERROR: Last file '{last_name}' not found in directory.")
        sys.exit(1)

    start_index = fits_files.index(first_name)
    end_index = fits_files.index(last_name)

    selected_files = fits_files[start_index:end_index + 1]

    print(f"\nProcessing {len(selected_files)} FITS files...\n")

    for fname in selected_files:
        full_path = os.path.join(directory, fname)
        process_single_file(full_path, f_out)

    f_out.close()
    print(f"\nOutput saved to: {output_file}\n")


# ------------------------------------------------------------
# Command Line Parsing
# ------------------------------------------------------------

if __name__ == "__main__":

    # SINGLE-FILE MODE
    if len(sys.argv) == 3:
        first_file = sys.argv[1]
        last_file = None
        output_file = sys.argv[2]
        main(first_file, last_file, output_file)
        sys.exit(0)

    # RANGE MODE
    if len(sys.argv) == 4:
        first_file = sys.argv[1]
        last_file = sys.argv[2]
        output_file = sys.argv[3]
        main(first_file, last_file, output_file)
        sys.exit(0)

    print("Usage:")
    print("  Single-file mode:")
    print("     python QuadStd.py <fits_file> <output_file>")
    print("")
    print("  Range mode:")
    print("     python QuadStd.py <first_fits> <last_fits> <output_file>")
    sys.exit(1)
