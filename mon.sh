#!/bin/bash
# Author: zhxfei

show_conn()
{
    data=`curl -s --connect-timeout 2 \
                "http://ip.taobao.com/service/getIpInfo.php?ip=$1"|jq .`
    if [ $(echo $data | jq .code) == 0 ];then
          loc=$(echo $data| jq ".data | [.country +.region +.city +.isp]| .[]")
          echo "client:$1 ; location: $loc ; conn_time: $2"
    else
        echo "requests fail; you could check the network configuration"
    fi
}

alertover()
{
    INFO=`show_conn $1 $2`
    echo $INFO
    NOTI=`curl -s \
          --form-string "source=s-b93ac1a7-5da7-4392-90aa-1eedcf20" \
          --form-string "receiver=u-7329c6d4-5104-417b-91a5-133f39ff" \
          --form-string "content=$INFO" \
          --form-string "title=shadowsocks monitor" \
          https://api.alertover.com/v1/alert |jq .`
    if [ $(echo $NOTI|jq .code) -ne 0 ];then
        echo $NOTI|jq .msg
    else
        echo "alert succeed"
    fi
}

inlog()
{
    grep $1 log.txt > /dev/null
    if [ $? -eq 0 ];then
        echo "client: $1 update count"
        COUNT=`grep $1 ./log.txt | awk '{print $NF}'`
        NEW_COUNT=$(($COUNT + $2))
        cat log.txt | grep -v $1 > log.txt
        INFO=`show_conn $1 $NEW_COUNT`
        echo $INFO >> log.txt
    else
        INFO=`show_conn $1 $2`
        echo $INFO >> log.txt
    fi
}

LINK_PEER=`ss -antp|grep "^ESTAB.*$1.*ssserver"| \
            awk '{print $5}'|awk -F: '{print $1}'| \
            sort|uniq -c |sort -nr|sed 's/^ \+//'|tr ' ' ':'`

[ -f ./log.txt ] || touch ./log.txt
[ -f ./know_host.txt ] || touch ./know_host.txt

for line in ${LINK_PEER};do
    COUNT=$(echo $line|awk -F':' '{print $1}')
    IP=$(echo $line|awk -F':' '{print $2}')
    grep $IP know_host.txt > /dev/null
    if [ $? -ne 0 ];then
        alertover $IP $COUNT
        echo $IP >> know_host.txt
    fi
    inlog $IP $COUNT
done
