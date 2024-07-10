
import os, sys
import cppyy
import time
import sys
import socket


print(f"GIAPI_ROOT: {os.environ.get('GIAPI_ROOT')}")
print(f"LD_LIBRARY_PATH: {os.environ.get('LD_LIBRARY_PATH')}")

giapi_root = os.environ.get('GIAPI_ROOT')

#these might not be working 
#still need to export LD_LIBRARY_PATH
cppyy.add_library_path(f"{giapi_root}/external/curlpp/lib64")
cppyy.add_library_path(f"{giapi_root}/install/lib")
cppyy.add_library_path(f"{giapi_root}/external/log4cxx/lib")
cppyy.add_library_path(f"{giapi_root}/external/activemq-cpp/lib")
cppyy.add_library_path(f"{giapi_root}/external/apr/lib")
cppyy.add_library_path(f"{giapi_root}/external/apr-util/lib")
cppyy.add_include_path(f"{giapi_root}/install/include")
cppyy.add_library_path(f"{giapi_root}/install/lib")

cppyy.include("giapi/StatusUtil.h")
cppyy.include("giapi/SequenceCommandHandler.h")
cppyy.include("giapi/CommandUtil.h")
cppyy.include("giapi/HandlerResponse.h")
cppyy.include("giapi/DataUtil.h")

cppyy.include("giapi/GeminiUtil.h")
cppyy.include("giapi/ServicesUtil.h")


cppyy.load_library(f"libapr-1.so.0")
cppyy.load_library(f"libexpat.so.0")
cppyy.load_library(f"libaprutil-1.so.0")
cppyy.load_library(f"liblog4cxx.so.11")
cppyy.load_library(f"libactivemq-cpp.so.14")
cppyy.load_library(f"libgiapi-glue-cc")
cppyy.add_include_path(f"{giapi_root}/src/examples/InstrumentDummyPython")
cppyy.include("DataResponse.h")
cppyy.include("InstCmdHandler.h")
from cppyy.gbl import giapi
from cppyy.gbl import instDummy


# Access the enum values
error_status = cppyy.gbl.giapi.status.Status.ERROR
ok_status = cppyy.gbl.giapi.status.Status.OK


import subprocess
import sys

def check_gmp_and_exit(gmp_host='localhost', gmp_port=8008):
    print(f"Checking GMP status on {gmp_host}:{gmp_port}")
    
    try:
        with socket.create_connection((gmp_host, gmp_port), timeout=5):
            print("GMP is available. ")
    except (socket.timeout, ConnectionRefusedError) as e:
        print(f"GMP is not available: {e}. Exiting.")
        sys.exit(1)
    except Exception as e:
        print(f"Error checking GMP: {e}. Exiting.")
        sys.exit(1)


    

class GiapiInterface:

    dataLabel = None

    def __init__(self):
        print("GIAPI init")

        self._callback_giapi = self.giapiCallback
        self._handler = instDummy.InstCmdHandler.create(self._callback_giapi)
        self.subscribeCommands()


    def subscribeCommands(self):
        print("GIAPI subscribe")

        #self._handler = instDummy.InstCmdHandler.create(self._callback_giapi)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.TEST, giapi.command.ActivitySet.SET_PRESET_START,self._handler)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.REBOOT, giapi.command.ActivitySet.SET_PRESET_START,self._handler)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.INIT, giapi.command.ActivitySet.SET_PRESET_START,self._handler)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.APPLY, giapi.command.ActivitySet.SET_PRESET,self._handler)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.OBSERVE, giapi.command.ActivitySet.SET_PRESET_START,self._handler)
        giapi.CommandUtil.subscribeSequenceCommand(giapi.command.SequenceCommand.ABORT, giapi.command.ActivitySet.SET_PRESET_START,self._handler)

    
        #print("---------------TESTING STUFF---------------")
        #self.getTCSContext()


        #giapi.DataUtil.postObservationEvent(giapi.data.ObservationEvent.OBS_PREP, "test label")

        #try: 
        #    hostname = giapi.ServicesUtil.getProperty("GMP_HOST_NAME", 2000)
        #    print(f"GMP_HOST_NAME: {path}")
        #except Exception as e:
        #    print(f"Exception while trying to get GMP_HOST_NAME from Gemini: {e}")
        
        #try: 
        #    path = giapi.ServicesUtil.getProperty("DHS_SCIENCE_DATA_PATH", 2000)
        #    print(f"PATH: {path}")
        #except Exception as e:
        #    print(f"Exception while trying to get DHS_SCIENCE_DATA_PATH from Gemini: {e}")
        
        #print("---------------DONE TESTING STUFF---------------")




    def getTCSContext(self):
        print("Getting TCS Context")
        ctx = giapi.TcsContext()

        try: 
            giapi.GeminiUtil.getTcsContext(ctx, 1000)
        except Exception as e:
            print(f"Exception while trying to get TCS Context from Gemini {e}")

        return ctx
    
    def printTCSContext(self, ctx):

        print("=================")
        print("Raw Time    :", ctx.time)
        print("Mount Flexure X :", ctx.x)
        print("Mount Flexure Y :", ctx.y)
        print("Mount Flexure Z :", ctx.z)
        print("=================\nTelescope Parameters ")
        print("Telescope focal length (mm)          :", ctx.tel.fl)
        print("Rotator mechanical angle (rads)        :", ctx.tel.rma)
        print("Azimuth axis tilt NS (rads)          :", ctx.tel.an)
        print("Azimuth axis tilt EW (rads)          :", ctx.tel.aw)
        print("Az/El nonperpendicularity (rads)       :", ctx.tel.pnpae)
        print("Net left-right(horizontal) collimation (rads) :", ctx.tel.ca)
        print("Net up-down(vertical) collimation (rads)   :", ctx.tel.ce)
        print("Pointing origin x-component (mm)       :", ctx.tel.pox)
        print("Pointing origin y-component (mm)       :", ctx.tel.poy)
        print("=================\nApparent to Observed Parameters ")

        for i in range(15):
            if i % 5 == 0:
                print()

            print( ctx.aoprms[i], end=" ")

        print()

        print("=================\nM2 tip/tilt (3 chop states) ")
        for x in range(3):
            for y in range(2):
                print( ctx.m2xy[x][y], end=" ")
            
            print()

        print("=================\nPoint Origins ")
        print("Mount point origin in X      :", ctx.po.mx)
        print("Mount point origin in Y      :", ctx.po.my)
        print("Source chop A pointing origin in X :", ctx.po.ax)
        print("Source chop A pointing origin in Y :", ctx.po.ay)
        print("Source chop B pointing origin in X :", ctx.po.bx)
        print("Source chop B pointing origin in Y :", ctx.po.by)
        print("Source chop C pointing origin in X :", ctx.po.cx)
        print("Source chop C pointing origin in Y :", ctx.po.cy)
        print("=================\nOptical Distortions ")
        for i in range(6):
            print(ctx.ao2t[i], end="   ")

        print()



    def handle_observation_event(self, event_type, event_description, data_label):
        try:
            # Call the C++ function and pass the specific event type
            if giapi.DataUtil.postObservationEvent(event_type, data_label) == error_status:
                print(f"Error: {event_description}")
            else:
                print(f"{event_description} Succeeded")

        except cppyy.gbl.GiapiException as e:
            print(f"Caught a GiapiException: {str(e)}")
        except Exception as e:
            print(f"An unexpected exception occurred: {str(e)}")        


    def observePrep(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_PREP, "Start Prep", data_label)

        
    def observeStartAcq(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_START_ACQ, "Start Acq", data_label)


    def observeEndAcq(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_END_ACQ, "End Acq", data_label)


    def observeStartReadout(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_START_READOUT, "Start Readout", data_label)


    def observeEndReadout(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_END_READOUT, "End Readout", data_label)


    def observeStartWrite(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_START_DSET_WRITE, "Start Dest Write", data_label)


    def observeEndWrite(self, data_label):
        self.handle_observation_event(giapi.data.ObservationEvent.OBS_END_DSET_WRITE, "End Dest Write", data_label)


    def giapiCallback(self, action_id, seq_cmd, activity, config):
        t = time.time()
        try:
            self.cur_action_id = action_id  # check!!! whether integer or not
            print(f'########## callGiapi python function {action_id} - {seq_cmd} {activity} ##########')
            print([f"{str(k)} : {config.getValue(k)}" for k in config.getKeys()])
            for k in config.getKeys():
                # TODO. It is necessary to do a regular expression instead of using split
                # It is necessary to know if the apply detector will consume more than 300 milisenconds 
                # in that case, it would be necessary to reponse with STARTED
                if seq_cmd == giapi.command.SequenceCommand.TEST:
                    print("SequenceCommand.TEST")
                    self.actRequested[action_id] = {'t' : t, 'response' : None, 'numAct':ACT_TEST}

                    if not (self.dcs_ready[SVC] and self.dcs_ready[H] and self.dcs_ready[K]):
                        print("instDummy.DataResponse:ERROR")
                        return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                    
                    if self.dc_core_busy[SVC] or self.dc_core_busy[H] or self.dc_core_busy[K]:
                        print("instDummy.DataResponse:ERROR")
                        return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                    
                    for idx in range(DCS_CNT):
                        self.dcs_setparam[idx] = False
                        
                    self.apply_mode = TEST_MODE
                    self.set_exp("all", 1.63, 1)
                    
                    print("instDummy.DataResponse:STARTED")
                    return instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                    
                elif seq_cmd == giapi.command.SequenceCommand.REBOOT:
                    print("SequenceCommand.REBOOT")
                    self.actRequested[action_id] = {'t' : t, 'response' : None, 'numAct':ACT_REBOOT}
        
                    for idx in range(DCS_CNT):
                        self.rebooting[idx] = True
                        
                    # -----------------------------------
                    # need to test with systemctl (InstSeq)
                    cfg = sc.LoadConfig(self.ini_file)
                    cfg.set(MAIN, "reboot", "True")
                    cfg.set(MAIN, "reboot-action-id", str(action_id))
                                        
                    sc.SaveConfig(cfg, self.ini_file)
                    
                    self.reboot = True
                    self.publish_to_queue(CMD_RESTART)
                    
                    #os.system("shutdown -r -f")
                    print("instDummy.DataResponse:STARTED")
                    return instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                    # -----------------------------------
                    
                elif seq_cmd == giapi.command.SequenceCommand.INIT:
                    print("SequenceCommand.INIT")
                    
                    self.actRequested[action_id] = {'t' : t, 'response' : None, 'numAct':ACT_INIT}
                    
                    if self.dc_core_busy[SVC] or self.dc_core_busy[H] or self.dc_core_busy[K]:
                        print("instDummy.DataResponse:ERROR")
                        return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                
                    for idx in range(DCS_CNT):
                        self.dcs_ready[idx] = False
                        
                    msg = "detectors do not initialized yet"
                    self.log.send(self.iam, ERROR, msg)
                    self.initialize2()
                    print("instDummy.DataResponse:STARTED")
                    return instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                                                            
                elif seq_cmd == giapi.command.SequenceCommand.APPLY:
                    print("SequenceCommand.APPLY")                    
                    keys = k.split(':')
                    # keys = ig2:dcs:expTime:1.63, ig2:seq:state:"acq" or "sci" ???
                    print(keys)
                    self.actRequested[action_id] = {'t': t, 'response': None, 'numAct': ACT_APPLY}
                    
                    if keys[2] == 'expTime':
                        self.cur_expTime = float(keys[3])
                        
                    elif keys[1] == "seq" and keys[2] == "state":
                        self.apply_mode = keys[3]
                        
                        if self.apply_mode == ACQ_MODE:
                            self.dcs_setparam[SVC] = False
                            if self.dc_core_busy[SVC]:
                                print("instDummy.DataResponse:ERROR")
                                return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                            
                            _exptime_acq = self.cur_expTime
                            self.set_exp(self.dcs_list[SVC], _exptime_acq, 1)
                            
                        elif self.apply_mode == SCI_MODE:
                            self.dcs_setparam[H] = False
                            self.dcs_setparam[K] = False
                            
                            if self.dc_core_busy[H] or self.dc_core_busy[K]:
                                print("instDummy.DataResponse:ERROR")
                                return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                            
                            _exptime_sci = self.cur_expTime
                            
                            _max_fowler_number = int((_exptime_sci - T_minFowler) / T_frame)
                            _FS_number_sci = N_fowler_max
                            while _FS_number_sci > _max_fowler_number:
                                _FS_number_sci //= 2
                                
                            self.set_exp("H_K", _exptime_sci, _FS_number_sci)
                                                    
                    #return
                
                elif seq_cmd == giapi.command.SequenceCommand.OBSERVE:
                    print("SequenceCommand.OBSERVE")
                    print([f"{str(k)} : {config.getValue(k)}" for k in config.getKeys()])



                    giapi.DataUtil.postObservationEvent(giapi.data.ObservationEvent.OBS_PREP, "datalabel")

                    #return instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                
                    keys = k.split(':')
                    print(keys)
                    self.actRequested[action_id] = {'t' : t, 'response' : None, 'numAct':ACT_OBSERVE}
                
                    if self.apply_mode == ACQ_MODE and self.dc_core_busy[SVC]:
                        print("instDummy.DataResponse:ERROR")
                        return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                
                    elif self.apply_mode == SCI_MODE and (self.dc_core_busy[H] or self.dc_core_busy[K]):
                        print("instDummy.DataResponse:ERROR")
                        return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                    
                    self.send_to_GDS(OBS_PREP)
                    self.send_to_GDS(OBS_STARTED_ACQ)
                    
                    if self.apply_mode == ACQ_MODE:
                        self.acquiring[SVC] = True
                        self.start_acquisition(self.dcs_list[SVC])
                        
                    elif self.apply_mode == SCI_MODE:
                        self.acquiring[H] = True
                        self.acquiring[K] = True
                        self.start_acquisition("H_K")

                    self.send_to_GMP("TCS_INFO")
                    
                    print("instDummy.DataResponse:STARTED")
                    return instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                    
                elif seq_cmd == giapi.command.SequenceCommand.ABORT:
                    print("SequenceCommand.ABORT")
                    self.actRequested[action_id] = {'t' : t, 'response' : None, 'numAct':ACT_ABORT}

                    if self.apply_mode == ACQ_MODE:
                        self.stop_acquistion(self.dcs_list[SVC])
                        print("instDummy.DataResponse:STARTED")
                        instDummy.DataResponse(giapi.HandlerResponse.STARTED, "")
                            
                    elif self.apply_mode == SCI_MODE:
                        self.stop_acquistion("H_K")  
                        print("instDummy.DataResponse:STARTED")
                        instDummy.DataResponse(giapi.HandlerResponse.TARTED, "")
                    
                '''
                #from getting the TCS info. PA!
                elif seq_cmd == giapi.command.SequenceCommand.TCS:  #temporarly
                    PA = "90"
                    msg = "%s %s" % (INSTSEQ_SHOW_TCS_INFO, PA)
                    self.publish_to_queue(msg)
                else:
                    print('Not implemented yet')
                    return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
                '''
                
                t2 = ti.time() - t
                while (t2 < 0.300):
                    ti.sleep(0.010)
                    if self.actRequested[action_id]['response'] == giapi.HandlerResponse.COMPLETED:
                        #break
                        print("instDummy.DataResponse:COMPLETED")
                        return instDummy.DataResponse(giapi.HandlerResponse.COMPLETED, "")
                    #print(t2)
                    t2 = ti.time() - t
                    
                if t2 >= 0.300 or self.actRequested[action_id]['response'] == giapi.HandlerResponse.ERROR:
                    print(f'Error detected time: {t2} seconds')
                    print("instDummy.DataResponse:ERROR")
                    return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")

        except Exception as e:
            print (e)
            print("instDummy.DataResponse:ERROR")
            return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")
        
        for k in self.actRequested:
            if self.actRequested[k] is None or self.actRequested[k]['response'] == giapi.HandlerResponse.ERROR:
                print("instDummy.DataResponse:ERROR")
                return instDummy.DataResponse(giapi.HandlerResponse.ERROR, "")

        #print("instDummy.DataResponse:COMPLETED")
        #return instDummy.DataResponse(giapi.HandlerResponse.COMPLETED, "")

#    async def wait_forever(self):
#        while True:
#            await asyncio.sleep(1)

if __name__ == "__main__":
    giapi_interface = GiapiInterface()
    #giapi_interface.subscribe_commands()


    while True:
        time.sleep(1)

#    loop = asyncio.get_event_loop()
#    loop.run_until_complete(giapi_interface.wait_forever())
    