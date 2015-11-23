## common functions
# 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
# Background color codes:
# 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white 

RED=$(    echo -e "\e[31;40m" ) 
GREEN=$(  echo -e "\e[32;40m" )
YELLO=$(  echo -e "\e[33;40m" )
BLUE=$(   echo -e "\e[34;40m" )
MAGENTA=$(echo -e "\e[35;40m" )
CYAN=$(   echo -e "\e[36;40m" )
RESET=$(  echo -e "\e[0m"     )


## export var
export LLLOCALIP
export LLLOG

## locale
export LANG=C
export LC_ALL=C

umask 022


# colourful print
#alias  msg=gmsg
msg()  { echo "${GREEN}$*${RESET}";   }
rmsg() { echo "${RED}$*${RESET}";     }
gmsg() { echo "${GREEN}$*${RESET}";   }
ymsg() { echo "${YELLO}$*${RESET}";   }
bmsg() { echo "${BLUE}$*${RESET}";    }
mmsg() { echo "${MAGENTA}$*${RESET}"; }
cmsg() { echo "${CYAN}$*${RESET}";    }

## get all interfaces ip addr
get_ipaddr()
{
    /sbin/ifconfig | awk '/inet addr:/ { if ($2 !~ /127.0.0.1/) { print substr($2,6)} } '
}

## get a lan ipaddr
get_localip()
{
    [[ -n "$LLLOCALIP" ]] && echo $LLLOCALIP && return 0

    local ip
    local default_ip=127.0.0.1
    for ip in $( echo $SSH2_CLIENT    | awk '{ print $3 }' ) \
              $( echo $SSH_CONNECTION | awk '{ print $3 }' ) \
              $( echo $SSH_CLIENT     | awk '{ print $1 }' ) \
              $( get_ipaddr ); do
       case $ip in
           172.*|192.*|10.*)
               echo $ip
               return 0
               ;;
       esac
    done

    # try to get eth1's ip as lan ip
    # if [[ -z "$LLLOCALIP" ]]; then
    #     LLLOCALIP=$(  /sbin/ifconfig eth1 | awk '/inet addr:/ {print substr($2,6)} ' )
    # fi

    # no lan ip ...
    if [[ -n "$LLLOCALIP" ]]; then
        echo $LLLOCALIP
        return 0
    else
        echo $default_ip
        return 1
    fi
}

# define LLLOCALIP
LLLOCALIP=$( get_localip )

# define LOG
if [[ -z "$LLLOG" ]]; then
    if [[ -n "$WORKDIR" ]]; then
        mkdir -p "$WORKDIR/log"
        LLLOG="$WORKDIR/log/log.$( get_localip )"
    else
        LLLOG="/tmp/log.$( get_localip )"
    fi
fi


# normal print and log
logmsg()
{
    local t=$( date '+%F %T' )
    local ip=$( get_localip  )
    gmsg "[$t $ip]: $*"
    echo "[$t $ip]: $*" >> "$LLLOG"
}

# warning
warn()
{
    local t=$( date '+%F %T' )
    local ip=$( get_localip  )
    mmsg "[$t $ip]WARNING: $*" >&2
    echo "[$t $ip]WARNING: $*" >> "$LLLOG"

}

# fatal, will exit
die()
{
    local t=$( date '+%F %T' )
    local ip=$( get_localip  )
    rmsg "[$t $ip]FATAL: $*" >&2
    echo "[$t $ip]FATAL: $*" >> "$LLLOG"
    exit 1
}

# return true / false
check_suseos()
{
    if [[ -f "/etc/SuSE-release" ]]; then
        grep -wqF 'SUSE' /etc/SuSE-release && return 0
    fi
    [[ -x /sbin/yast2 ]]  && return 0 || :
    
    return 1
}

# return true / false
check_slkos()
{
    if [[ -f "/etc/slackware-version" ]]; then
        grep -wqF 'Slackware' /etc/slackware-version &>/dev/null && return 0
    fi
    [[ -x /sbin/installpkg ]]  && return 0 || :

    return 1
}

# return true / false
check_rhos()
{
    if [[ -f /etc/redhat-release ]]; then
        grep -wqi  red /etc/redhat-release &>/dev/null && return 0
    fi

    return 1
}
# 
get_osinfo()
{
    if check_suseos; then
        xargs < /etc/SuSE-release
    elif check_slkos; then
        xargs < /etc/slackware-version
    elif check_rhos; then
        xargs < /etc/redhat-release
    else
        lsb_release -d 2>/dev/null || echo 'UNKNOWD OS'
    fi
}


## get all lan ipaddr
#  not perfect, as some ip range may in 10.x.x.x ...
get_localip_all()
{
    local ip
    for ip in $( get_ipaddr ); do
       case $ip in
           172.*|192.*|10.)
               echo $ip
               #return
               ;;
       esac
    done
}

## return 32/64, based on OS not hardware
get_cputype()
{
    if uname -a | grep -Fq 'x86_64'; then
        echo 64
        return
    else
        echo 32
        return
    fi
}

## return a version like 2.4 / 2.6
get_kernver()
{
    /sbin/kernelversion 2>/dev/null ||
        uname -r | grep -o '^2\..'
}

## add a line to crontab
add_cron()
{
    local cmd="$1"
    local key

    for c in $cmd; do
        case $c in
            /*)
                key=$( basename $c )
                break
                ;;
        esac
    done

    if [[ -z "$key" ]]; then
        warn "[$cmd] not use abs_path to command, not allowed added to crontab"
        return 1
    fi

    if [[ ! -x "$c" ]]; then
        warn "[$c] not executable, not allowed added to crontab"
        return 1
    fi

    if crontab -l | grep -F -v '#' | grep -Fqw "$key"; then
        warn "[$cmd] not add to crontab, as keyword [$key] found in crontab"
    else
        crontab -l |
        {   
          cat 
          echo -e "\n## auto added by $0 at $(date '+%F %T')"
          echo  "$cmd"
        } |
        crontab -
    fi
}    

## trim leading space and tailing space
trim()
{
    sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//'
}

## check if a string in a file which is not commented
is_str_infile()
{
    local str="$1"
    local file="$2"

    grep -Fv '#' "$file" | grep -Fwq "$str"

    return $?
}

## rename a file or dir to make sure the filename or dirname would be OK to reuse
## if "abc" exits, it will be renamed as "abc.old"
remove_old()
{
    local name="$1"
    local oldname="${name}.old"

    if [[ -e "$name" ]] || [[ -L "$name" ]]; then
        :
    else
        return
    fi

    [[ -e "$oldname" ]] && rm -rf "$oldname"
    [[ -L "$oldname" ]] && rm -rf "$oldname"

    /bin/mv "$name" "$oldname"
}

## kill a process if it's running
try_kill_proc()
{
    local proc="$1"

    if killall -0 "$proc" &>/dev/null; then
        if killall -9 "$proc"; then
            logmsg "found old "$proc" running, kill OK"
        else
            die "found old "$proc" running, kill FAILED"
        fi
    fi
}

## get tarball dirname    /1/2/3/abc.tar.bz -> abc
get_tarball_dirname()
{
    local tb="$1"
    case $tb in
        *.tar.bz2|*.tar.gz)
            echo $tb | sed -e 's@.*/@@g' -e 's@\.tar\.\(bz2\|gz\)$@@'
            ;;
        *.tgz|*.tbz)
            echo $tb | sed -e 's@.*/@@g' -e 's@\.\(tbz\|tgz\)$@@'
            ;;
        *)
            echo $tb
    esac
}

## return bzip2 / gzip
get_tarball_type()
{
    file "$1" | grep -Fq 'bzip2 compressed data' && echo bzip2 || echo gzip
}

## test.tgz is true ,test is false
is_tarball_file()
{
    echo "$1" | egrep '*.tgz$|*.tbz$|*.tar$|*.bz2$|*.gz$'
}
## to grep multipul times, supposed to be used after a pipe or with read redirection
mgrep()
{
    local key="$1"
    local opt=

    if [[ -z "$key" ]]; then
        cat     
        return  
    fi

    while [[ ${key:0:1} == '-' ]]; do
        opt="$opt $key"
        shift
        key="$1"
    done

    shift   
    grep $opt $key | mgrep $@
}

## a simple mktemp. some old os have no /bin/mktemp
mktemp()
{
    local opt=$1

    # # suse
    # /bin/mktemp $opt 2> /dev/null && return 0
    # # slk 10
    # /usr/bin/mktemp $opt /tmp/tmp.XXXXXX 2> /dev/null && return 0
    # # slk 8.1
    # /usr/bin/mktemp XXXXXX 2> /dev/null && return 0

    local tmp="/tmp/$$.$RANDOM.$( date +%s )"
    [[ $opt == "-d" ]] && mkdir "$tmp" || touch "$tmp"
    RC=$?
    (( RC == 0 )) || return $RC
    echo $tmp
}

## file/dir must be there
must_exist()
{
    local t
    local flag=
    for t; do
        if [[ -e "$t" ]]; then
            logmsg "[$t] FOUND"
        else
            flag=1
            warn "[$t] NOT FOUND"
        fi
    done

    (( flag == 1 )) && die "FILES NOT FOUND, ABORTING ..."
}

## get free capacity of a partition by a filename/pathname
get_free_cap()
{
    local path=$1
    if [[ ! -e "$path" ]]; then
        echo 0B
        return
    fi

    ## df so cool!
    df -h "$path" | awk 'NR==2 { print $4 }'
}


## get sizes of files by du
get_file_size()
{
    local file=$1
    ## do not quote [$file], may contain more than one filename
    local size=$( du -sh $file  2>/dev/null | awk '{ print $1; exit }' || echo 0B )
    echo ${size: -1} | grep -q '^[0-9]$' && size=${size}B
    echo ${size:-0B}
}

ubuntu_pack_check()
{
    apt-get update
    apt-get autoremove -y
    apt-get -fy install
    apt-get install -y build-essential gcc g++ make
    for packages in build-essential gcc g++ make automake autoconf re2c wget cron bzip2 libzip-dev libc6-dev file rcconf flex nano
    do apt-get install -y $packages --force-yes;apt-get -fy install;apt-get -y autoremove; done
}

_get_char()
{
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

wait()
{
    warn "Press any key to continue...or Press Ctrl+c to cancel"
    char=$(_get_char)
    logmsg "you enter $char. continued........................................."
}
