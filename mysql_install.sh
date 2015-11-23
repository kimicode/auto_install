#! /bin/bash

## check if mysql is runing
if netstat --inet -lpn 2>/dev/null | grep --color mysql; then
    die "MYSQL maybe running ..."
fi
if netstat --inet -lpn 2>/dev/null | grep --color ':3306'; then
    die "PORT 3306 is listening ..."
fi

source ./lib_install_comm.sh -f mysql -c "--with-charsets=complex --with-extra-charsets=complex"

PORT='3306'
MYSQL_DAEMON="$INSTALL_DIR/bin/mysqld_safe"
MYCNF=$WORKDIR/conf/my.cnf

cd "$LNK" || die "cd $LNK FAILED"

[[ -d /data/mysql_data ]] || mkdir -p /data/mysql_data

logmsg "add user/group for mysql ..."
{
    groupadd mysql 
    useradd -g mysql mysql
} 2>/dev/null

remove_old /etc/my.cnf
logmsg "copy $MYCNF --> /etc/my.cnf ..."
remove_old /etc/my.cnf
cp "$MYCNF" /etc/my.cnf

localip=$( get_localip )

case $localip in
    172.*|192.*|10.*)
        ;;
    *)
        localip=127.0.0.1
        ;;
esac

## to avoid binding in outlan IP
logmsg "modify my.cnf to bind address on [$localip] ..."
if [[ -z "$localip" ]]; then
    die "get localip FAILED"
fi

perl -ni -e 'BEGIN{ $ip = pop @ARGV; } print $_; print "bind-address\t= $ip\n" if /^\[mysqld\]/' /etc/my.cnf "$localip"
perl -pi -e 'BEGIN{ $ip = pop @ARGV; } s/^\s*(bind-address)\s*=.*/$1\t= $ip/ if /^\s*bind-address/' /etc/my.cnf "$localip"


## make sure we can resolv $HOSTNAME or localhost
if ! is_str_infile 'localhost' /etc/hosts; then
    echo 127.0.0.1 localhost >> /etc/hosts
fi
if ! is_str_infile "$HOSTNAME" '/etc/hosts'; then
    echo $localip   $HOSTNAME >> /etc/hosts
fi

logmsg "initialize mysql database ..."
$INSTALL_DIR/bin/mysql_install_db >> $LLLOG || die "initialize mysqldb FAILED"
chown -R mysql.mysql /data/mysql_data "$INSTALL_DIR" /etc/my.cnf

logmsg "try to startup mysqld ..."
"$MYSQL_DAEMON" &
MYSQL_PID=$?

if kill -0 $MYSQL_PID; then
    logmsg "mysqld start OK"
fi

sleep 1
echo
logmsg "checking netstat ..."
netstat --inet -lpn
echo; echo
## again, color printing
netstat --inet -lpn | grep -E --color "$localip:$PORT[[:space:]]+.*mysqld" ; RC=$?

if (( $RC != 0 )); then
    warn "mysql seems not bond on local, KILLING ..."
    netstat --inet -lpn | grep --color mysql
    ./bin/mysqladmin shutdown
    try_kill_proc "mysqld"
    exit 1
fi

if check_suseos; then
    if rpm -q mysql-client &>/dev/null; then
        logmsg "old mysql-client client rpm found, removing ..."
        rpm -e mysql-client 
    fi
fi


logmsg "update ld.so.conf"
if ! is_str_infile "$LNK/lib/mysql" '/etc/ld.so.conf'; then
    echo "$LNK/lib/mysql" >> '/etc/ld.so.conf'
    logmsg "updating /etc/ld.so.conf ..."
    ldconfig
fi


logmsg "adding mysql in rc.local to autostart at machine staring ..."
echo "## $( date '+%F_%T' ) added by $0" >> /etc/rc.d/rc.local
echo "$MYSQL_DAEMON &" >> /etc/rc.d/rc.local

echo
logmsg "All done"
