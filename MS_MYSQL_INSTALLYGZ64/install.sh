#!/bin/bash

usage()
{
    cat <<EOF
MySQL 安装脚本使用说明
安装数据库前请
rm -rf /usr/local/mysql
rm -rf /export/mysql
Usage:$0 [OPTION] [str] 
   -h     help              
   -m     master mysql的域名或者ip地址
   -s     slave mysql的域名或者ip地址
   -n     指对几个mysql配置快照，如果mysql端口是3306 ，这个
          值应该是1，如果是3307，应该是2，以此类推。
   -p     数据库的密码
   -f     不安装数据库只主从复制配置 
   
EOF
exit
}


[ $# == 0 ] && usage 
MASTER=''
SLAVE=''
FLAG=0
NUM=''
SNAPSHOT=''
TYPE=''


while getopts ":m:s:p:n:fkt:" opts;do
  case $opts in
	h)
		usage
		;;
	m)
		MASTER=$OPTARG
		;;
	s)
		SLAVE=$OPTARG
		;;
	f)
		FLAG=1
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


if [[ $SLAVE != ''  ]];then
	if [[ $NUM == '' ]];then
		echo -e "\033[31m 如果指定了slave,-n 的值不能为空  \033[0m"
		exit
	fi

	PORT=`expr 3305 + $NUM`	
fi



if [[ $MASTER != '' && $FLAG != 1 ]];then

	ssh -p 30022  $MASTER "/bin/ps aux|grep -v grep |grep mysql"
	if [[ $? == 0  ]];then
		echo -e "\033[31m  $MASTER mysql 数据库已经存在  \033[0m"
		exit
	fi

fi


if [[ $SLAVE != '' && $FLAG != 1 ]];then

	ssh -p 30022  $SLAVE "/usr/sbin/lsof -i:$PORT"
	if [[ $? == 0  ]];then
		echo -e "\033[31m  ${SLAVE}:${PORT} mysql 数据库已经存在  \033[0m"
		exit
	fi

fi


###check system environment

if [[ $MASTER != '' && $FLAG != 1 ]];then

	MASTER=`/bin/ping $MASTER -c 1  |grep "PING"| awk -F ') ' '{print $1}'|awk -F "(" '{print $2}' |head -n 1`
	
	ssh -p 30022  $MASTER "mkdir -p /export/tmp"

	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` start scp -P 30022 -r mysql_install $MASTER:/export/tmp/  \033[0m"
	scp -P 30022 -r mysql_install $MASTER:/export/tmp/
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` end scp -P 30022 -r mysql_install $MASTER:/export/tmp/  \033[0m"
	
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始在${MASTER}安装mysql数据库  \033[0m"
	ssh -p 30022  $MASTER "cd /export/tmp/mysql_install/;sh mysql_install.sh -t master -p '$DBPWD'"

	if [[ $DBPWD == '' ]];then
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql -e '\s'"
		if [[ $? != 0 ]];then
			echo -e "\033[31m \033[05m 数据库安装失败 \033[0m"
			exit 1
		fi		
	else
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql -uroot -p'$DBPWD' -e '\s'"
		if [[ $? != 0 ]];then
			echo -e "\033[31m \033[05m 数据库安装失败 \033[0m"
			exit
		fi		
	fi

	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 在${MASTER}安装mysql数据库结束  \033[0m"
	
fi

if [[ $SLAVE != '' && $FLAG != 1 ]];then
	SLAVE=`/bin/ping $SLAVE -c 1  |grep "PING"| awk -F ') ' '{print $1}'|awk -F "(" '{print $2}' |head -n 1`

	ssh -p 30022  $SLAVE "mkdir -p /export/tmp${PORT}"

	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` start scp -P 30022 -r mysql_install $SLAVE:/export/tmp${PORT}/  \033[0m"
	scp -P 30022 -r mysql_install $SLAVE:/export/tmp${PORT}/
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` end scp -P 30022 -r mysql_install $SLAVE:/export/tmp${PORT}/  \033[0m"
	
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始在${SLAVE}安装mysql数据库  \033[0m"
	ssh -p 30022  $SLAVE "cd /export/tmp${PORT}/mysql_install/;sh mysql_install.sh -t slave -n $NUM -p '$DBPWD'"

	if [[ $DBPWD == '' ]];then
		ssh -p 30022  $SLAVE "/usr/local/mysql${PORT}/bin/mysql -S /tmp/mysql${PORT}.sock -e '\s'"
		if [[ $? != 0 ]];then
			echo -e "\033[31m \033[05m 数据库安装失败 \033[0m"
			exit
		fi		
	else
		ssh -p 30022  $SLAVE "/usr/local/mysql${PORT}/bin/mysql -S /tmp/mysql${PORT}.sock -uroot -p'$DBPWD' -e '\s'"
		if [[ $? != 0 ]];then
			echo -e "\033[31m \033[05m 数据库安装失败 \033[0m"
			exit
		fi		
	fi
	
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 在${SLAVE}安装mysql数据库结束  \033[0m"




	
fi

if [[ $SLAVE != '' && $MASTER != ''  ]];then
	
	MASTER=`/bin/ping $MASTER -c 1  |grep "PING"| awk -F ') ' '{print $1}'|awk -F "(" '{print $2}' |head -n 1`
	SLAVE=`/bin/ping $SLAVE -c 1  |grep "PING"| awk -F ') ' '{print $1}'|awk -F "(" '{print $2}' |head -n 1`
	MYSQLBIN="/usr/local/mysql${PORT}/bin"
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始 $MASTER ${SLAVE} 主从复制配置  \033[0m"
	
	if [[ $DBPWD == '' ]];then
		#授权slave 所需的用户 		
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql  -e \"grant replication slave on *.* to mysqlrepl@'$SLAVE' identified by 'mysqlrepl'\" "

		#开始备份 MASTER 数据库数据
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始备份 $MASTER 数据 \033[0m"
		mkdir -p data
		BAKFILE="data/${MASTER}_`date +'%Y%m%d_%H_%M'`.bak"
		DATABASES=`ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql  -N -e 'show databases'|egrep -v 'information_schema|performance_schema'"`
		DATABASES=`echo $DATABASES`
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysqldump -vv -hlocalhost  --skip-opt --create-options --add-drop-table --single-transaction -q -e --set-charset --master-data=2 -K -R --triggers --hex-blob --events  --databases  $DATABASES  " > $BAKFILE 
		if [[ $? != 0 ]];then
			echo -e "\033[31m\033[05m备份$MASTER数据失败 \033[0m"
			exit
		fi
		

		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 备份$MASTER数据结束 \033[0m"

		#将master备份数据导入slave数据库
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始导入$MASTER的数据到$SLAVE \033[0m"
		set -o pipefail
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -vvv  -S /tmp/mysql${PORT}.sock" < $BAKFILE|grep -A 5 INSERT|sed 's/VALUES.*//g'
		
		if [[ $? != 0 ]];then
			echo -e "\033[31m\033[05m导入$MASTER的数据到$SALVE失败 \033[0m"
			exit
		fi

		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 导入$MASTER的数据到$SLAVE结束\033[0m"
	
		LOGPOS=`head -n 30  $BAKFILE|egrep 'CHANGE MASTER' |sed 's/-- CHANGE MASTER TO//g'`
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql  -S /tmp/mysql${PORT}.sock -e \" stop slave;change master to  master_host='$MASTER', master_user='mysqlrepl',master_password='mysqlrepl', $LOGPOS start slave  \""
		sleep 2
		PNUM=`ssh -p 30022  $SLAVE "$MYSQLBIN/mysql  -S /tmp/mysql${PORT}.sock -e \"show slave status\G \" |egrep \"Slave_IO|Slave_SQL\"|grep 'Yes'|wc -l"`
		LASTERR=`ssh -p 30022  $SLAVE "$MYSQLBIN/mysql  -S /tmp/mysql${PORT}.sock -e 'show slave status\G '"|egrep Error`
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql  -S /tmp/mysql${PORT}.sock -e \"flush privileges\" "

	else
		#授权slave 所需的用户 		
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql -uroot -p'$DBPWD' -e \"grant replication slave on *.* to mysqlrepl@'$SLAVE' identified by 'mysqlrepl'\" "

		#开始备份 MASTER 数据库数据
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始备份 $MASTER 数据 \033[0m"
		mkdir -p data
		BAKFILE="data/${MASTER}_`date +'%Y%m%d_%H_%M'`.bak"
		DATABASES=`ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysql -uroot -p'$DBPWD' -N -e 'show databases'|egrep -v 'information_schema|performance_schema'"`
		DATABASES=`echo $DATABASES`
		ssh -p 30022  $MASTER "/usr/local/mysql/bin/mysqldump -uroot -p'$DBPWD' -vv -hlocalhost  --skip-opt --create-options --add-drop-table --single-transaction -q -e --set-charset --master-data=2 -K -R --triggers --events  --hex-blob   --databases $DATABASES  " > $BAKFILE
		if [[ $? != 0 ]];then
			echo -e "\033[31m\033[05m备份$MASTER数据失败 \033[0m"
			exit
		fi
		

		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 备份$MASTER数据结束 \033[0m"

		#将master备份数据导入slave数据库
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 开始导入$MASTER的数据到$SLAVE \033[0m"
		set -o pipefail
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -vvv -uroot -p'$DBPWD'  -S /tmp/mysql${PORT}.sock" < $BAKFILE|grep -A 5 INSERT|sed 's/VALUES.*//g'
		
		if [[ $? != 0 ]];then
			echo -e "\033[31m\033[05m导入$MASTER的数据到$SALVE失败 \033[0m"
			exit
		fi
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` 导入$MASTER的数据到$SLAVE结束\033[0m"

		#主从配置
		LOGPOS=`head -n 30  $BAKFILE|egrep 'CHANGE MASTER' |sed 's/-- CHANGE MASTER TO//g'`
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -uroot -p'$DBPWD' -S /tmp/mysql${PORT}.sock -e \" stop slave;change master to  master_host='$MASTER', master_user='mysqlrepl',master_password='mysqlrepl', $LOGPOS start slave  \""
		sleep 2
		PNUM=`ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -uroot -p'$DBPWD'  -S /tmp/mysql${PORT}.sock -e \"show slave status\G \" |egrep \"Slave_IO|Slave_SQL\"|grep 'Yes'|wc -l"`
		LASTERR=`ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -uroot -p'$DBPWD' -S /tmp/mysql${PORT}.sock -e 'show slave status\G '"|egrep Error`
		ssh -p 30022  $SLAVE "$MYSQLBIN/mysql -uroot -p'$DBPWD' -S /tmp/mysql${PORT}.sock -e \"flush privileges\" "


	fi

	if [[ $PNUM == 2 ]];then
		echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` $MASTER $SLAVE 主从复制成功 \033[0m"
		test -f $BAKFILE && rm -rf $BAKFILE
	else
		echo -e "\033[31m\033[05m##`date +"%Y-%m-%d %H:%M:%S"` $MASTER $SLAVE 主从复制失败 \033[0m"
		echo $LASTERR
		test -f $BAKFILE && rm -rf $BAKFILE
		exit
	fi
	
	echo -e "\033[31m##`date +"%Y-%m-%d %H:%M:%S"` $MASTER $SLAVE 主从复制配置结束 \033[0m"

fi

