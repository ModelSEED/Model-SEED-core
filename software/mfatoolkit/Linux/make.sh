cd $1"software/mfatoolkit/Linux/"
export GLPKDIRECTORY=$2
if [ $3 != "nocplex" ] then
    export CPLEXDIRECTORY=$3
fi
if [ $4 == "clean" ] then
    make clean
fi
make