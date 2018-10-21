deps_config := \
	/mnt/hgfs/share/build_system_kit/components/cjson/Kconfig \
	/mnt/hgfs/share/build_system_kit/Kconfig

include/config/auto.conf: \
	$(deps_config)


$(deps_config): ;
