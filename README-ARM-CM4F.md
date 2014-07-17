ObjFW on Bare-Metal ARM (Cortex-M4F)
====================================
This file contains instructions on how to get a working build environment to 
compile ObjFW on Bare-Metal ARM.  

Prerequisites
-------------

* Cortex-M4F hardware with external RAM  
  **Cortex-M4 without FPU should be fine. Cortex-M3 is not tested yet.**
* clang/llvm 3.5 (http://clang.llvm.org/get_started.html)  
  **You need 3.5 or later. Build from source is highly recommended.**
* GNU Tools for ARM Embedded (https://launchpad.net/gcc-arm-embedded)

***Tested environment is:***

* Ubuntu 14.04 LTS
* Silabs EFM32WG-DK3850
* clang version 3.5.0 (trunk 210986)
* gcc-arm-none-eabi-4_8-2014q2-20140609-linux

Additional setup
----------------

Make an symbolic link to make clang happy.

    cd /path_to_toolchain
    ln -s arm-none-eabi usr

Put these bash scripts into your GNU tools bin folder. (Don't add .sh extension, 
and don't forget to chmod +x)

***arm-none-eabi-clang***

```
/path_to_llvm/bin/clang --target=armv7em-unknown-none-eabi -isysroot /path_to_toolchain $@
```

***armv7em-unknown-none-eabi-gcc***

```
#!/bin/bash

for ARG in "$@"
do
	if [[ $ARG != -fobjc* ]] && \
	   [[ $ARG != -fconstant-string-class* ]] && \
	   [[ $ARG != -fblocks ]] && \
	   [[ $ARG != -fno-constant-cfstrings* ]]
	then
		NEW_ARGS="$NEW_ARGS $ARG"
	fi
done

arm-none-eabi-gcc --specs=rdimon.specs $NEW_ARGS
```

Build
-----

    ./autogen.sh
    ./configure --host=arm-none-eabi --with-cm4f
    make

To run the tests or your application, you need to perform linkage on your 
development environment.  
You gonna need additional link options something like this. (Be careful with 
the --whole-archive option. Otherwise, categories will not be loaded properly.)

    --specs=nosys.specs -Wl,--whole-archive -lobjfw-tests -Wl,--no-whole-archive
