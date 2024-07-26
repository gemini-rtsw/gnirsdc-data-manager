from caproto.server import PVGroup, pvproperty
import shutil

class DiskSpacePVGroup(PVGroup):
    # Define the PVs for total, used, and free disk space
    total_space = pvproperty(value=0.0, precision=2, units='Bytes')
    used_space = pvproperty(value=0.0, precision=2, units='Bytes')
    free_space = pvproperty(value=0.0, precision=2, units='Bytes')

    # This method updates the PVs with current disk space data
    @total_space.startup
    async def total_space(self, instance, async_lib):
        # Runs when the IOC starts up
        while True:
            # Get disk space for the specified location
            total, used, free = shutil.disk_usage("/")

            # Update the PV values
            await self.total_space.write(total)
            await self.used_space.write(used)
            await self.free_space.write(free)

            # Sleep for some time before next update
            await async_lib.library.sleep(60)  # update every minute