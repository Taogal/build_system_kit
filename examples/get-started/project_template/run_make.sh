#!/bin/bash


if [ $BSD_PATH ]; then
    echo "BSD_PATH:"
    echo "$BSD_PATH"
    echo ""
else
    echo "ERROR: Please run the shell file called set_bsd_environment.sh in the BSD dir firstly!"
    echo "eg:"
    echo "	root@ubuntu:#source set_bsd_environment.sh"
    echo ""
    echo "ERROR: Please export BSD_PATH firstly, exit!!!"
    exit
fi

echo "run_make.sh version 20181012"
echo ""

echo "start..."
echo ""

make clean


make app