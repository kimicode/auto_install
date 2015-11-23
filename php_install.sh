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
#########################################################################


source ./lib_install_comm.sh -f php -c "--with-apxs2=/usr/local/apache/bin/apxs --with-mysql=/usr/local/mysql \
--with-pdo-mysql=/usr/local/mysql --with-curl --with-curlwrappers  --enable-socket --with-libxml-dir=/usr/local/libxml2 \
--with-curl=/usr/local/curl"

logmsg "cp php config file....."
mkdir -p /usr/local/php/etc
if [ -e $WORKDIR/conf/php.ini ];then 
    cp $WORKDIR/conf/php.ini /usr/local/php/etc/
    logmsg "use $WORKDIR/conf/php.ini"
else
    cp ./php.ini-development /usr/local/php/etc/php.ini
    sed -i 's#; extension_dir = "./"#extension_dir = "/usr/local/php/lib/"\n\#extension = "memcache.so"\n#' /usr/local/php/etc/php.ini
    sed -i 's/;date.timezone =/date.timezone = PRC/g' /usr/local/php/etc/php.ini
    logmsg "use ./php.ini-development"
fi
