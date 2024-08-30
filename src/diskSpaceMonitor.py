from caproto.server import PVGroup, pvproperty
import shutil

class DiskSpacePVGroup(PVGroup):
    # Define the PVs for total, used, and free disk space
    total_space = pvproperty(value=0.0, precision=2, units='GB')
    used_space = pvproperty(value=0.0, precision=2, units='GB')
    free_space = pvproperty(value=0.0, precision=2, units='GB')

    @staticmethod
    def bytes_to_gb(bytes_value):
        return round(bytes_value / (1024 ** 3), 2)

    @total_space.startup
    async def total_space(self, instance, async_lib):
        while True:
            # Get disk space for the specified location
            total, used, free = shutil.disk_usage("/")

            # Convert bytes to GB and update PV values
            await self.total_space.write(self.bytes_to_gb(total))
            await self.used_space.write(self.bytes_to_gb(used))
            await self.free_space.write(self.bytes_to_gb(free))

            # Sleep for some time before next update
            await async_lib.library.sleep(60)  # update every minute