echo ""
echo "Assembling DSP code Aladdin"
echo ""
set include=..\compil_DSP56K\CLAS563\BIN
%include%\asm56300 -b -l tim.ls -d DOWNLOAD HOST -d WAVEFORM_FILE "AladdinIII.waveforms" tim.asm
%include%\dsplnk -b tim.cld -v tim.cln
del AladdinIII_SDSU_Firmware.lod
%include%\cldlod tim.cld > AladdinIII_SDSU_Firmware.lod
del tim.cln
del tim.cld
