#!/bin/bash
############################
# SCRIPT: mysql_install.sh 
# AUTHOR: liqingbin	   
# DATE:   2014-8-19        
############################


MYSQLITAR='mysql-5.5.39-linux2.6-x86_64.tar.gz'

usage()
{
    cat <<EOF
MySQL 安装脚本使用说明
安装之前请确认已经删除/usr/local/mysql,
/export/mysql 目录，设置密码请加上单引号。
脚本安装之前会 rm -rf /usr/local/mysql，
/export/mysql
Usage:$0 -t [master|slave] 
   -h     help              
   -t     安装的数据库的类型master或者slave。 区别:master
	  的server-id为1,salve的server-id为2
   -n     slave 编号，安装多实例时使用。
   -p     mysql root用户密码 
EOF
exit
}
[ $# == 0 ] && usage 

NUM=''

while getopts ":ht:p:n:" opts;do
  case $opts in
	h)
		usage
		;;
	t)
		TYPE=$OPTARG
		if  ! [[ $TYPE == 'master' || $TYPE == 'slave' ]];then
			usage	
		
		fi
		;;
	p)
		DBPWD=$OPTARG
		;;
	n)
		NUM=$OPTARG
		;;
	*)
		-$OPTARG unvalid
		usage;;
  esac
done



if [[ $NUM != '' ]];then
	PORT=`expr 3305 + $NUM`
fi	

#install mysql#
rm -rf  /usr/local/mysql${PORT}
rm -rf /export/mysql${PORT}

useradd mysql
mkdir -p /export/mysql${PORT}/mysqllog/redolog
mkdir -p /export/mysql${PORT}/mysqllog/slowquery
mkdir -p /export/mysql${PORT}/mysqllog/binlog
mkdir -p /export/mysql${PORT}/mysqllog/relaylog
mkdir -p /export/mysql${PORT}/mysqldata/data
mkdir -p /export/mysql${PORT}/mysqldata/ibdata

MYSQLIDIR=`echo $MYSQLITAR|sed 's/.tar.gz//g'`
tar xvf $MYSQLITAR
\mv -f  $MYSQLIDIR /usr/local/mysql${PORT}
chown -R mysql:mysql /usr/local/mysql${PORT}
chown -R mysql:mysql /export/mysql${PORT}
\cp -a mysource1 /etc/my.cnf


MEM1=`awk 'NR==1{print int($2/1024*0.3)}' /proc/meminfo`
BMEM1=`echo $MEM1|awk '{if($1 > 1024) {printf "%d%s" ,int($1/1024),"G" } else {printf "%d%s",($1),"M"} }'`

###slave启了三个实例
MEM2=`awk 'NR==1{print int($2/1024*0.6/3)}' /proc/meminfo`
BMEM2=`echo $MEM2|awk '{if($1 > 1024) {printf "%d%s" ,int($1/1024),"G" } else {printf "%d%s",($1),"M"} }'`
BMEM2=5G

if [[ $TYPE == 'slave' ]];then
	\cp -a mysource /usr/local/mysql${PORT}/my.cnf
	sed -i '/^server-id/ c server-id = 2' /usr/local/mysql${PORT}/my.cnf
	sed -i "s/\/export\/mysql\//\/export\/mysql${PORT}\//" /usr/local/mysql${PORT}/my.cnf
	sed -i "/^socket/ c socket     = /tmp/mysql${PORT}.sock" /usr/local/mysql${PORT}/my.cnf
	sed -i "/^port/ c port =  ${PORT}"  /usr/local/mysql${PORT}/my.cnf
	sed -i "/^innodb_buffer_pool_size/ c innodb_buffer_pool_size = ${BMEM2}" /usr/local/mysql${PORT}/my.cnf
else
	\cp -a mysource /etc/my.cnf
	sed -i "/^innodb_buffer_pool_size/ c innodb_buffer_pool_size = ${BMEM1}" /etc/my.cnf
fi


/usr/local/mysql${PORT}/scripts/mysql_install_db  --basedir=/usr/local/mysql${PORT} --datadir=/export/mysql${PORT}/mysqldata/data  --user=mysql


sed -i "/nproc/d"  /etc/security/limits.conf
sed -i "/nofile/d"  /etc/security/limits.conf
echo "*        soft    nproc           65535" >> /etc/security/limits.conf
echo "*        hard    nproc           65535" >> /etc/security/limits.conf
echo "*        soft    nofile           65535" >> /etc/security/limits.conf
echo "*        hard    nofile           65535" >> /etc/security/limits.conf

if /usr/bin/test -f /etc/security/limits.d/90-nproc.conf ;then
  sed -i "/nproc/d"  /etc/security/limits.d/90-nproc.conf 
  echo "*        soft    nproc           65535" >> /etc/security/limits.d/90-nproc.conf
  echo "*        hard    nproc           65535" >> /etc/security/limits.d/90-nproc.conf
fi


sed  -i  "/\/usr\/local\/mysql${PORT}\/bin/"d /etc/profile
echo "export PATH=/usr/local/mysql${PORT}/bin:\$PATH ">>/etc/profile
/sbin/sysctl -p

\cp -a  mysql.server /etc/init.d/mysqld${PORT}

sed -i "s/\/usr\/local\/mysql/\/usr\/local\/mysql${PORT}/" /etc/init.d/mysqld${PORT}

sed -i "s/\/export\/mysql\//\/export\/mysql${PORT}\//" /etc/init.d/mysqld${PORT}

chmod +x /etc/init.d/mysqld${PORT} 
/sbin/chkconfig --add mysqld${PORT}
/sbin/chkconfig mysqld${PORT} on
/etc/init.d/mysqld${PORT} start


if [[ $TYPE == 'slave' ]];then
	mysqldir=/usr/local/mysql${PORT}/bin
	$mysqldir/mysql -S /tmp/mysql${PORT}.sock  -e "delete from mysql.user where user='';"
	$mysqldir/mysql -S /tmp/mysql${PORT}.sock   -e "delete from mysql.user where host='';"
	$mysqldir/mysql -S /tmp/mysql${PORT}.sock   -e "grant all on *.* to root@'127.0.0.1' identified by '$DBPWD'"
	$mysqldir/mysqladmin -S /tmp/mysql${PORT}.sock   password  $DBPWD

	if [[ $DBPWD == '' ]];then
		/usr/local/mysql${PORT}/bin/mysql -S /tmp/mysql${PORT}.sock  -e "use mysql"
		FLAG=$?
	else
		/usr/local/mysql${PORT}/bin/mysql -S /tmp/mysql${PORT}.sock -uroot -p$DBPWD  -e "use mysql"
		FLAG=$?
	fi

else
	mysqldir=/usr/local/mysql/bin
	$mysqldir/mysql  -e "delete from mysql.user where user='';"
	$mysqldir/mysql  -e "delete from mysql.user where host='';"
	$mysqldir/mysql  -e "grant all on *.* to root@'127.0.0.1' identified by '$DBPWD'"
	$mysqldir/mysqladmin  password  $DBPWD

	if [[ $DBPWD == '' ]];then
		/usr/local/mysql${PORT}/bin/mysql   -e "use mysql"
		FLAG=$?
	else
		/usr/local/mysql${PORT}/bin/mysql  -uroot -p$DBPWD  -e "use mysql"
		FLAG=$?
	fi

fi

if [[ $FLAG == 0  ]];then
	echo -e "\033[31m  数据库安装完毕 \033[0m"  
	echo -e "\033[32m 1、安装脚本已经将mysql设为系统的自启动服务器 \033[0m"		  
	echo -e "\033[32m 2、mysql服务管理工具使用方法：/etc/init.d/mysqld${PORT}  {start|stop|restart|reload|force-reload|status}  \033[0m"  
	echo -e "\033[32m 3、mysql命令的全路径: /usr/local/mysql${PORT}/bin/mysql  \033[0m"  
	echo -e "\033[32m 4、重开一个session，可使用mysql -S  /tmp/mysql${PORT}.sock  -uroot -p 进入mysql。  \033[0m"  
	echo -e "\033[32m 5、数据库的root密码: $DBPWD  \033[0m" 
else
	echo -e "\033[31m \033[05m 数据库安装失败 \033[0m" 
	exit 1
fi

