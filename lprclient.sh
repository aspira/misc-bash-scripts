SPOOLFILE=$1
IPADDRESS=$2
QUEUE=$3
OLDSTTY=`stty --save`
ME=`basename $0`
USER=`whoami`
HOST=`hostname`
JOBNUM=$[ ( $RANDOM % 1000 ) ]
BACKFILE=`mktemp`
CONTROLFILE=`mktemp`

CONTROLFILENAME="cfA$JOBNUM$HOST"
DATAFILENAME="dfA$JOBNUM$HOST"

>$BACKFILE
stty raw
( 

# setup control file
(
	echo -ne "H$HOST\x0a"
	echo -ne "P$USER\x0a"
	echo -ne "J$JOBNUM\x0a"
	echo -ne "l$DATAFILENAME\x0a"
	echo -ne "U$DATAFILENAME\x0a"
	echo -ne "N$SPOOLFILE\x0a"
	
) > $CONTROLFILE

getack()
{
	# TODO: Test if the file is empty
	sleep 1 # we get around this by waiting
	BYTEINBIN=`od -N1 $BACKFILE | cut -d" " -f 2 | head -1` # convert one byte from BACKFILE, output the second field on the first line of the od output
	
	if [ "$BYTEINBIN" = "000000" ]
	then
		echo "OK $BYTEINBIN" >&2
		>$BACKFILE
		return 0
	else
		echo "ERR $BYTEINBIN" >&2
		>$BACKFILE
		return 1
	fi
}

getfilesize()
{
	echo -ne `stat -c %s $1`
}
CONTROLFILESIZE=`getfilesize $CONTROLFILE`
DATAFILESIZE=`getfilesize $SPOOLFILE`
#SIZE=70

echo -ne "\x02$QUEUE\x0a" # tell print queue
getack
echo -ne "\x02$CONTROLFILESIZE $CONTROLFILENAME\x0a" # Receive control file
getack
cat $CONTROLFILE
echo -ne "\x00" # end the file
getack
echo -ne "\x03$DATAFILESIZE $DATAFILENAME\x0a"
getack
cat $SPOOLFILE
echo -ne "\x00"
getack
exit 0
) | nc $IPADDRESS 515 | tee -a $BACKFILE
stty $OLDSTTY

rm $BACKFILE
rm $CONTROLFILE