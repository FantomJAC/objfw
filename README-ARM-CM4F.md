ObjFW on Bare-Metal ARM (Cortex-M)
====================================
This file contains instructions on how to get a working build environment to 
compile ObjFW on Bare-Metal ARM.  

Prerequisites
-------------

* Cortex-M hardware with external RAM  
* CMSIS-RTOS implementation (for the threading)  
  **Only Keil RTX is supported so far.**
  **To use the threading feature, you have to implement your own syscalls supports reentrancy and thread-safety.**
* clang/llvm 3.5 (http://clang.llvm.org/get_started.html)  
  **You need 3.5 or later. Build from source is highly recommended.**
* GNU Tools for ARM Embedded (https://launchpad.net/gcc-arm-embedded)

### Tested environment

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

---
***arm-none-eabi-clang***

This script makes clang to do actual cross-compiling for Cortex-M.

```
/path_to_llvm/bin/clang --target=arm-none-eabi \
-march=armv7e-m -mthumb -mfloat-abi=softfp -mfpu=fpv4-sp-d16 \
-isysroot /path_to_toolchain $@
```

---
***arm-none-eabi-gcc***

For the script below, you first need to rename the original gcc.

    cd /path_to_toolchain/bin
    mv arm-none-eabi-gcc arm-none-eabi-gcc.real

This script is to filter objc options that is passed by clang.

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

arm-none-eabi-gcc.real $NEW_ARGS
```

Build
-----

Before you continue, make sure that /path_to_toolchain/bin was added to PATH.

    ./autogen.sh
    export LDFLAGS=--specs=rdimon.specs
    export CMSIS=/path_to_cmsis_dir
    ./configure --host=arm-none-eabi --with-cmsis
    make

To run the tests or your application, you need to perform linkage on your 
development environment.  
You gonna need additional link options something like this. (Be careful with 
the --whole-archive option. Otherwise, categories will not be loaded properly.)

    --specs=nosys.specs -Wl,--whole-archive -lobjfw-tests -Wl,--no-whole-archive
