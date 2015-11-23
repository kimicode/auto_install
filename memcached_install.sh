#!/bin/bash
#########################################################################
# Author: lincolnlin
# Created Time: Sun 02 Sep 2012 12:34:03 AM CST
# File Name: test_func_common.sh
# Description: memcached 自动安装脚本
# 脚本实现功能：
#  1.自动选择和下午相应的安装包
#  2.自动检测安装环境
#  3.安装过程中失败可自行解决后，从失败点运行
#  4.安装结束后包括更新ld.so.conf ,配置文件初始化和服务启动
# 下个版本改进：增加 APP_URL 通过配置读取
#########################################################################

WORKDIR=$( dirname $0 )
cd "$WORKDIR"
export WORKDIR="$(pwd)"

if [[ ! -r "$WORKDIR/func-common.sh" ]]; then
    echo "ERROR: $WORKDIR/func-common.sh NOT FOUND"
fi

. "$WORKDIR/func-common.sh"

#系统全局变量定义============================================================
APP_PARAM=                 #SHELL传入APP参数
APP_URL="http://www.xxx.com/"
APP=			#全文件名 如libevent-1.2.3.tgz
VER= 			#带版本号的部分文件名 如libevent-1.2.3

APP_NAME=  #单纯的APP名称，如libevent
LINK=       #INSTALL_DIR 最后要作软链接到该路径
INSTALL_DIR=

#CONFIG=  注意这个地方不能加双引号，不然后续再引用到就变成双重引号
CONFIG="-with-libevent=/usr/local/libevent"


APP_KEY=       #用于查找软件包的优先KEY［version or update time ］

#为全局变量赋值============================================================
if [ $# -eq "0" ]  # 不带命令行参数就调用脚本?
then
  die "Usage: `basename $0` options
  -k the primority for the app packet [time|verion] 
  -f the app[*.tgz |*] 必填
  -u the url 
  -c the configure param "
fi  


while getopts ":ak:f:u:c:" Option
do
  case $Option in
    a ) echo "Scenario #5: option -$Option-";;
    k     ) APP_KEY=$OPTARG;;
    f     ) APP_PARAM=$OPTARG;;
    u     ) APP_URL=$OPTARG;;
    c     ) CONFIG=$OPTARG;;
    *     ) warn "Unimplemented option chosen.";;   # DEFAULT
  esac
done

# 解析出APP VER两个变量
logmsg "cd packets"
cd packets || die 'cd packets error'
if [[ -n "$APP_PARAM" ]]; then
    #如果是TAR文件名，直接将其作为安装文件，否则在packets文件夹中找一个适合的
    if [[ $(is_tarball_file $APP_PARAM) ]];then 
	    if [[ -e "$APP_PARAM" ]];then 
	        VER=$( get_tarball_dirname "$APP_PARAM" )
	        APP=$APP_PARAM
	    else
	        die "the specified app file $APP_PARAM not found"
	    fi
    else
        if [[ ! -n "$APP_KEY" ]];then 
	        APP_KEY="version"
        fi

    	case $APP_KEY in 
	    "version" ) #the last version
	        APP=$(  ls -1  |grep "$APP_PARAM-*" 2>/dev/null|sort -r | sed '1q' )
		VER=$( get_tarball_dirname "$APP" )
	        ;;
	    "time" )   #the last update file
	        APP=$(  ls -1t |grep  $APP_PARAM 2>/dev/null | sed '1q' )
		VER=$( get_tarball_dirname "$APP" )
	        ;;
	    *)
	        ;;
	    esac

	 #判断文件是否需要下载
	 if [[ ! -e "$APP" ]];then
	      wget "$APP_URL" -c  && echo "wget $APP_URL SUCCESS!" ||die "wget $APP_URL FAILED .....APP:$APP VER:$VER"
	 fi
    fi
else
    die "miss -f param"
fi


APP_NAME=$(echo $VER |awk -F'-' '{print $1}')
INSTALL_DIR="/usr/local/$VER"
LINK="/usr/local/$APP_NAME"
logmsg "APP:$APP" 
logmsg "VER:$VER"
logmsg "APP_NAME:$APP_NAME"
logmsg "INSTALL_DIR:$INSTALL_DIR"
logmsg "LINK:$LINK"


#检查系统安装环境是否正常==============================================================
# Check if user is root
if [ $(id -u) != "0" ]; then
    die "Error: You must be root to run this script, please use root"
fi

## check if memcached is runing
if netstat --inet -lpn 2>/dev/null | grep --color memcached; then
    die "Memcached maybe running ..."
fi
if netstat --inet -lpn 2>/dev/null | grep --color ':11211'; then
    die "PORT 11211 is listening ..."
fi

# Check install dir exists
if [ -e "$INSTALL_DIR" ]; then
    warn "$INSTALL_DIR [found]. are you sure to remove it"
    wait
    remove_old $INSTALL_DIR
fi
if [ -e "$LINK" ]; then
    warn "$LINK [found]. are you sure to remove it"
    wait
    remove_old $LINK
fi

#installing==============================================================
logmsg "unpacking $APP ..."
if [[ $( get_tarball_type ) == 'bzip' ]]; then
    tar xjf "$APP"
else
    tar xzf "$APP"
fi
cd "$VER" || die "Can not cd into $(pwd)/$VER"


logmsg "configure ..."
logmsg "./configure --prefix=$INSTALL_DIR $CONFIG" 

while (( 1==1 ))
do
    ./configure "--prefix="${INSTALL_DIR} ${CONFIG}  >> "$LLLOG"  2>&1 && break
    warn "CONFIGURE ERROR! please resolve the problem and press any key to try again!"
    wait
done

logmsg "make ..."
while (( 1==1 ))
do
    make   >> "$LLLOG"  2>&1 && break
    warn "MAKE ERROR! please resolve the problem and press any key to try again!"
    wait
done

logmsg "make install ..."
while (( 1==1 ))
do
    make install >> "$LLLOG"  2>&1 && break
    warn "MAKE INSTALL ERROR! please resolve the problem and press any key to try again!"
    wait
done

logmsg "making symbol link ..."
ln -sf "$INSTALL_DIR" "$LINK" >>"$LLLOG" 2>&1

#添加动态库到LDCONFIG
if ! is_str_infile "$LINK/lib/" '/etc/ld.so.conf'; then
    echo "$LINK/lib/" >> '/etc/ld.so.conf'
    logmsg "updating /etc/ld.so.conf ..."
    ldconfig
fi


#add tools
logmsg "cp memcached tool to $INSTALL_DIR"
cp $WORKDIR/conf/memcached-init $INSTALL_DIR/bin/
chmod +x $INSTALL_DIR/bin/memcached-init

localip=$(get_localip)

sed -i "s/127.0.0.1/$localip/g" $INSTALL_DIR/bin/memcached-init

logmsg "Starting Memcached..."
$INSTALL_DIR/bin/memcached-init start >> "$LLLOG"  2>&1
if ps aux|grep memcached |grep -v grep ;then 
  logmsg "memcached started"
else 
  logmsg "memcached start failed!"
fi

logmsg "===================== install $APP_PARAM completed ====================="
logmsg "======================================================================="
