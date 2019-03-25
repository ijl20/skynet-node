#!/usr/bin/wish -f

source skynet.tcl

sky_connect [sky_hosts all closed]


sky_bfp_one [sky_hosts 30] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 27] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 24] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 21] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 18] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 15] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 12] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 9] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 6] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 3] overbeek 70
sky_wait

sky_bfp_one [sky_hosts 1] overbeek 70
sky_wait


sky_disconnect [sky_hosts all]
