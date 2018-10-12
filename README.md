## About this repository
a build system kit embed from [esp-idf](https://github.com/espressif/esp-idf).



## 1.How to use?

	$cd build_system_kit
    $source set_bsd_environment.sh
    
    $cd PRJ_DIR
    $make menuconfig
    $./run_make.sh
   
**Use the make help for more shell cmd:**

![](make_help.png)


You can create you project like the $(BSD_PATH)/examples.

Problems:
**make menuconfig cannot work?**

    $apt-get update
    $apt-get install libncurses5-dev
    
    $cd ./tools
    $./kconfig/lxdialog/check-lxdialog.sh -ccflags

The result for make menuconfig:
![](menuconfig.png)

 


  