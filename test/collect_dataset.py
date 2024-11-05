#!/usr/bin/env python3

import os
import time
from epics import caput, camonitor

#os.environ['EPICS_CA_ADDR_LIST'] = "127.0.0.1"



# Global flag to track sequence activity
readout_complete = False
readout_started = False



def on_state_change(pvname=None, value=None, **kw):
    global readout_complete
    global readout_started

    print(f"State change detected in {pvname}: {value}")
    if value == 0:
        print("Controller IDLE")
        if readout_started:
            print("Readout Complete")
            readout_complete = True
            readout_started = False
    elif value == 2:
        print("Readout Started")
        readout_started = True




# Attach monitor to the channel
camonitor("tgnirs:dc:applyC.VAL", callback=on_state_change)

# Load settings from config
set_config = open('./collect_config.txt', "r")
lines = set_config.readlines()
set_config.close()



for line in lines:


    set_info = [val for val in line.split()]
    print(f"Starting Set {set_info[0]} - {set_info[1]}")

    readout_complete = False
    caput("tgnirs:dc:readUpTheRamp", set_info[5], wait=True)
    caput("tgnirs:dc:lnrNum", set_info[0])
    caput("tgnirs:dc:digitalAvgs", set_info[1])
    caput("tgnirs:dc:dropReadoutsNum", set_info[3], wait=True)
    caput("tgnirs:dc:sequence", set_info[2], wait=True)
    caput("tgnirs:dc:arSetup.H", set_info[4], wait=True)
    caput("tgnirs:dc:labelTimeStamp", 1, wait=True)
    caput("tgnirs:archive_fits", 0, wait=True)
    caput("tgnirs:include_eng", set_info[6], wait=True)
    caput("tgnirs:dc:observe.DIR", "MARK", wait=True)
    caput("tgnirs:dc:apply.DIR", "START")

    #wait for readout to start - PUT BACK IN IF IT CRASHES
    #print("waiting for sequence to complete")
    while not readout_complete:
        time.sleep(1)


    time.sleep(2)

    print("Complete")

print ("All sets complete")

# Additional cleanup if necessary
# epics.camonitor_clear("tgnirs:dc:applyC.VAL")

#Note:  set_info parameters are as follows
# 0:  LNRS
# 1:  ADC digitalAvgs
# 2:  Sequence - #of exposures
# 3:  Drop Frames - used in up-the-ramp mode
# 4:  Well-depth:  Can only be 0.3 or 0.6
# 5:  Up-the-ramp mode?  0 for normal, 1 for up-the-ramp mode
# 6:  Include engineering data: 0 for no, 1 for yes
