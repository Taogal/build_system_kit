## About this repository
a build system kit embed from [esp-idf](https://github.com/espressif/esp-idf).



##1.How to use?

	cd build_system_kit
    export $BSD_PATH= [pwd's result] #build_system_kit dir
    
    make menuconfig
    make app V=1
    
Use the make help for more shell cmd.


You can create you project like the $(BSD_PATH)/examples.

Problems:

    make menuconfig cannot work:
    cd ./tools
    ./kconfig/lxdialog/check-lxdialog.sh -ccflags
     
    apt-get update
    apt-get install libncurses5-dev
   

The result for make menuconfig:
![](menuconfig.png)

 


  