#!/usr/bin/env bash
# Copyright (C) 2014 Olaf Lenz
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


# HELPER FUNCTIONS

# output value of env variables
function outp {
    for p in $*; do
        echo "  $p=${!p}"
    done
}

# start a block
function start {
    echo "=================================================="
    echo "START $1"
    echo "=================================================="
}

# end a block
function end {
    echo "=================================================="
    echo "END $1"
    echo "=================================================="
}

# execute and output a command
function cmd {
    echo ">$1"
    eval $1
}


# handle environment variables
[ -z "$insource" ] && insource="true"
[ -z "$srcdir" ] && srcdir=`pwd`
[ -z "$configure_params" ] && configure_params=""
[ -z "$configure_vars" ] && configure_vars=""
[ -z "$with_mpi" ] && with_mpi="true"
[ -z "$with_fftw" ] && with_fftw="true"
[ -z "$with_tcl" ] && with_tcl="true"
[ -z "$with_python_interface" ] && with_python_interface="false"
[ -z "$myconfig" ] && myconfig="default"
! $with_mpi && check_procs=1
[ -z "$check_procs" ] && check_procs=4
[ -z "$make_check" ] && make_check="true"

if $insource; then
    builddir=$srcdir
elif [ -z "$builddir" ]; then
    builddir=$srcdir/build
fi

outp insource srcdir builddir \
    configure_params configure_vars with_mpi with_fftw \
    with_tcl with_python_interface myconfig check_procs

if ! $insource; then
    if [ ! -d $builddir ]; then
        echo "Creating $builddir..."
        mkdir -p $builddir
    fi
fi

# BOOTSTRAP
start "BOOTSTRAP"
$srcdir/bootstrap.sh || exit $?
end "BOOTSTRAP"

if ! $insource ; then
    cd $builddir
fi

# CONFIGURE
start "CONFIGURE"

if $with_mpi; then
    configure_params="--with-mpi $configure_params"
    configure_vars="CXX=mpic++"
else
    configure_params="--without-mpi $configure_params"
fi

FFTW_HEADER=$srcdir/src/core/fftw3.h
if $with_fftw; then
    configure_params="--with-fftw $configure_params"
else
    configure_params="--without-fftw $configure_params"
    echo "Not using FFTW => generating mock $FFTW_HEADER..."
    echo "#error ERROR: fftw is not really present but used somewhere." \
        > $FFTW_HEADER
fi

if $with_tcl; then
    configure_params="--with-tcl $configure_params"
else
    configure_params="--without-tcl $configure_params"
fi

if $with_python_interface; then
    configure_params="--with-python-interface $configure_params"
else
    configure_params="--without-python-interface $configure_params"
fi

cmd "$srcdir/configure $configure_params $configure_vars" || exit $?
end "CONFIGURE"

# BUILD
start "BUILD"

MYCONFIG_DIR=$srcdir/maintainer/jenkins/configs
if [ "$myconfig" = "default" ]; then
    echo "Using default myconfig."
else
    myconfig_file=$MYCONFIG_DIR/$myconfig.hpp
    if [ ! -e "$myconfig_file" ]; then
        echo "$myconfig_file does not exist!"
        exit 1
    fi
    echo "Copying $myconfig.hpp to $builddir/myconfig.hpp..."
    cp $myconfig_file $builddir/myconfig.hpp
fi

cmd "make" || exit $?

end "BUILD"

# CHECK
if $make_check; then
    start "TEST"

    cmd "make check $make_params"
    ec=$?
    if [ $ec != 0 ]; then
        cat $srcdir/testsuite/runtest.log
        exit $ec
    fi

    end "TEST"
fi
