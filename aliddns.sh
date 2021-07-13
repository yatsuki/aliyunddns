#!/bin/bash

# +------------------------------------
# | AliyunDDns Script v0.1
# +------------------------------------
# | 阿里云DDNS解析脚本版 V0.1
# | 一键将DNS解析到指定位置,方便非固定ip实现动态解析.
# | 一键DDNS用法:
# |   export Ali_Key=xxx
# |   export Ali_Secret=xxx
# |   export Ali_Domain=example.com
# |   aliddns.sh -m --record blog --value $(curl -s icanhazip.com)
# |     此命令可作为cron定时任务,定时检查解析
# | 设置解析:
# |   aliddns.sh -a --record blog --type A --value 0.0.0.0
# | 修改解析:
# |   aliddns.sh -m --record blog --value 0.0.0.0
# | 删除解析:
# |   aliddns.sh -r blog
# +------------------------------------
# | Author: ohnoku
# | Blog: https://blog.lintian.co
# | Email: yorutsuki@live.com
# +------------------------------------
                                       
# =========== Code Start Here =========

# 字体颜色定义
Font_Black="\033[30m"  
Font_Red="\033[31m" 
Font_Green="\033[32m"  
Font_Yellow="\033[33m"  
Font_Blue="\033[34m"  
Font_Purple="\033[35m"  
Font_SkyBlue="\033[36m"  
Font_White="\033[37m" 
Font_Suffix="\033[0m"
# 消息提示定义
Msg_Info="${Font_Blue}[Info] ${Font_Suffix}"
Msg_Warning="${Font_Yellow}[Warning] ${Font_Suffix}"
Msg_Debug="${Font_Yellow}[Debug] ${Font_Suffix}"
Msg_Error="${Font_Red}[Error] ${Font_Suffix}"
Msg_Success="${Font_Green}[Success] ${Font_Suffix}"
Msg_Fail="${Font_Red}[Failed] ${Font_Suffix}"
Msg_Autofix="${Font_SkyBlue}[AutoFix] ${Font_Suffix}"

Version=V0.1
Update=2021-07-12

# 简易JSON解析器
PharseJSON() {
    # 使用方法: PharseJSON "要解析的原JSON文本" "要解析的键值"
    # Example: PharseJSON ""Value":"123456"" "Value" [返回结果: 123456]
    echo -n $1 | grep -oP '(?<='$2'":)[0-9A-Za-z]+'
    if [ "$?" = "1" ]; then
        echo -n $1 | grep -oP ''$2'[" :]+\K[^"]+'
        if [ "$?" = "1" ]; then
            echo -n "null"
            return 1
        fi
    fi
}

# AliDNS API - 获取时间戳
GetTimeStamp() {
    local Timestamp="`date -u "+%Y-%m-%dT%H%%3A%M%%3A%SZ"`"
    echo -n $Timestamp
}

# AliDNS API - 获取签名随机数
# 使用两个字符串合并，增强签名的随机性，确保在连续请求API时不会发生签名重复问题
SignatureNonce() {
    local RandomString1="`date +%s%N`"
    local RandomString2="`cat /proc/sys/kernel/random/uuid`"
    local SignatureNonce="AliyunDDNS-$RandomString1-$RandomString2"
    echo -n $SignatureNonce
}

# AliDNS API - URL签名相关函数
URLEncode() {
    echo -n "$1" | URLEncode_Action
}

URLEncode_Action() {
    local out=""
    while read -n1 c
    do
        case $c in
            [a-zA-Z0-9.~_-]) out="$out$c" ;;
            *) out="$out`printf '%%%02X' "'$c"`" ;;
        esac
    done
    echo -n $out
}

AliDnsSendRequest() {
    #
    echo -e "${Msg_Info}[云解析API] 正在初始化请求..."
    Var_RequestResult=""
    Var_ResponseCode=""

    # +-----公共参数(必须)---------------
    # | Format=JSON
    # | Version=2015-01-09
    # | AccessKeyId
    # | Signature (最后发送请求前生成)
    # | SignatureMethod=HMAC-SHA1
    # | Timestamp
    # | SignatureVersion=1.0
    # | SignatureNonce
    # +--------------------------------

    # 公共请求参数(包含换行符)
    local Var_ComArgs=`echo -e "Format=json\nVersion=2015-01-09\nAccessKeyId=$Ali_Key\nSignatureMethod=HMAC-SHA1\nTimestamp=$(GetTimeStamp)\nSignatureVersion=1.0\nSignatureNonce=$(SignatureNonce)"`
    # 组合接口参数并排序(最后会多一个&)
    local Val_AllArgs=`echo -e "$Var_ComArgs\n$1" | sort | tr "\n" "&"`
    # 删除最后多余的&
    Val_AllArgs=${Val_AllArgs%?}
    # 请求参数(去掉最后一个&并URL编码)
    local Var_RequestArgs=`echo -e $(URLEncode "${Val_AllArgs}")`
    # Hash签名过程
    local Var_RequestHash=$(echo -n "GET&%2F&$Var_RequestArgs" | openssl dgst -sha1 -hmac "$Ali_Secret&" -binary | openssl base64)
    # 发送请求, 并将结果传给 RequestResult 变量
    echo -e "${Msg_Info}[云解析API] 正在发送请求..."
    Var_RequestResult="`curl -s "https://alidns.aliyuncs.com/?$Val_AllArgs&Signature=$(URLEncode "$Var_RequestHash")"`"
    # 解析返回结果是否出现了错误
    echo ${Var_RequestResult} | grep -E "\"Code\"|\"Message\"" >/dev/null 2>&1
    if [ "$?" = "0" ]; then
        # 发生错误, 显示错误日志
        echo -e "${Msg_Error}[云解析API] API端返回了一个错误 !"
        echo -e "${Msg_Info}错误代码: `PharseJSON "${Var_RequestResult}" "Code"`"
        echo -e "${Msg_Info}错误详细信息: `PharseJSON "${Var_RequestResult}" "Message"`"
        echo -e "${Msg_Debug}Request ID: `PharseJSON "${Var_RequestResult}" "RequestId"`"
        echo -e "${Msg_Debug}错误代码详细信息: `PharseJSON "${Var_RequestResult}" "Recommend"`"
        Var_ResponseCode="1"
        return 1
    else
        echo -e "${Msg_Info}[云解析API] 请求发送成功 !"
        Var_ResponseCode="0"
        return 0
    fi
}

AliDNSAdd() {
    echo -e "${Msg_Info}[AliDNSAdd] 新增DNS解析记录"
    # 参数检查
    if [ ${#Ali_Domain} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] Domain信息未设置!"
        exit 1
    elif [ ${#Ali_Key} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] AccessKey未设置!"
        exit 1
    elif [ ${#Ali_Secret} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] Secret未设置!"
        exit 1
    elif [ ${#Var_Record} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] 新增解析记录时Record是必须项!"
        exit 1
    elif [ ${#Var_Type} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] 新增解析记录时Type是必须项!"
        exit 1
    elif [ ${#Var_Value} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSAdd] 新增解析记录时Value是必须项!"
        exit 1
    fi
    
    # +-----该接口参数-------------------
    # | Action=AddDomainRecord
    # | DomainName=$Ali_Domain
    # | RR=$Var_Record
    # | Type=$Var_Type
    # | Value=$Var_Value
    # +---------------------------------
    local Var_AddArgs=`echo -e "Action=AddDomainRecord\nDomainName=$Ali_Domain\nRR=$Var_Record\nType=$Var_Type\nValue=$Var_Value"`

    # 发送请求
    AliDnsSendRequest "$Var_AddArgs"
    # 检查结果
    if [ "$Var_ResponseCode" -eq "1" ]; then
        local Var_ResultCode="`PharseJSON "${Var_RequestResult}" "Code"`"
        if [ "$Var_ResultCode" = "DomainRecordDuplicate" ]; then
            echo -e "${Msg_Error}[AliDNSAdd]解析记录($Var_Record.$Ali_Domain -> [$Var_Type]$Var_Value)在本账户下已存在, 请不要重复添加 !"
        fi
        exit 1
    else
        echo -e "${Msg_Success}[AliDNSAdd]解析记录($Var_Record.$Ali_Domain -> [$Var_Type]$Var_Value) 添加成功 !"
        exit 0
    fi
}

AliDNSModify() {
    echo -e "${Msg_Info}[AliDNSModify] 修改DNS解析记录"
    # 参数检查
    if [ ${#Ali_Domain} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSModify] Domain信息未设置!"
        exit 1
    elif [ ${#Ali_Key} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSModify] AccessKey未设置!"
        exit 1
    elif [ ${#Ali_Secret} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSModify] Secret未设置!"
        exit 1
    elif [ ${#Var_Record} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSModify] 修改解析记录时Record是必须项!"
        exit 1
    elif [ ${#Var_Value} -eq 0 ]; then
        echo -e "${Msg_Error}[AliDNSModify] 修改解析记录时Value是必须项!"
        exit 1
    fi
    # 首先获取原解析记录
    # +-----接口参数-------------------
    # | Action=DescribeDomainRecords
    # | DomainName=$Ali_Domain
    # | KeyWord=$Var_Record
    # | SearchMode=EXACT
    # +---------------------------------
    local Var_ListArgs=`echo -e "Action=DescribeDomainRecords\nDomainName=$Ali_Domain\nKeyWord=$Var_Record\nSearchMode=EXACT"`

    # 发送请求
    AliDnsSendRequest "$Var_ListArgs"
    # 检查结果
    if [ "$Var_ResponseCode" = "1" ]; then
        echo -e "${Msg_Error}[AliDNSModify]解析记录($Var_Record.$Ali_Domain)查询失败!"
        exit 1
    else
        local Var_RecordCnt="`PharseJSON "${Var_RequestResult}" "TotalCount"`"
        if [ "$Var_RecordCnt" = "0" ]; then
            echo -e "${Msg_Error}[AliDNSModify]解析记录($Var_Record.$Ali_Domain)不存在!"
            exit 1
        fi
    fi

    local Var_RecordId="`PharseJSON "${Var_RequestResult}" "RecordId"`"
    local Var_RecordType="`PharseJSON "${Var_RequestResult}" "Type"`"
    local Var_RecordValue="`PharseJSON "${Var_RequestResult}" "Value"`"
    
    if [ "$Var_Value" = "$Var_RecordValue" ]; then
        echo -e "${Msg_Warning}[AliDNSModify]解析记录($Var_Record.$Ali_Domain -> $Var_Value)修改值一致,不需要修改!"
        exit 1
    fi
    
    # 修改解析记录
    # +-----接口参数-------------------
    # | Action=UpdateDomainRecord
    # | RR=$Var_Record
    # | RecordId=$Var_RecordId
    # | Type=$Var_RecordType
    # | Value=$Var_Value
    # +---------------------------------
    local Var_ModifyArgs=`echo -e "Actioon=UpdateDomainRecord\nRR=$Var_Record\nRecordId=$Var_RecordId\nType=$Var_RecordType\nValue=$Var_Value"`
    # 发送请求
    AliDnsSendRequest "$Var_ModifyArgs"
    if [ "$Var_ResponseCode" -ne "0" ]; then
        echo -e "${Msg_Error}解析记录[AliDNSModify]($Var_Record.$Ali_Domain -> $Var_Value)修改失败!"
        exit 1
    else
        echo -e "${Msg_Success}解析记录[AliDNSModify]($Var_Record.$Ali_Domain -> $Var_Value)修改成功!"
        exit 0
    fi
}

AliDNSRemove() {
    echo -e "${Msg_Info}[AliDNSRemove] 删除DNS解析记录"
# 参数检查
    if [ ${#Ali_Domain} -eq 0 ]; then
        echo -e "${Msg_Error}[$AliDNSRemove] Domain信息未设置!"
        exit 1
    elif [ ${#Ali_Key} -eq 0 ]; then
        echo -e "${Msg_Error}[$AliDNSRemove] AccessKey未设置!"
        exit 1
    elif [ ${#Ali_Secret} -eq 0 ]; then
        echo -e "${Msg_Error}[$AliDNSRemove] Secret未设置!"
        exit 1
    elif [ ${#Var_Record} -eq 0 ]; then
        echo -e "${Msg_Error}[$AliDNSRemove] 删除解析记录时Record是必须项!"
        exit 1
    fi
    # 首先获取原解析记录
    # +-----接口参数-------------------
    # | Action=DescribeDomainRecords
    # | DomainName=$Ali_Domain
    # | KeyWord=$Var_Record
    # | SearchMode=EXACT
    # +---------------------------------
    local Var_ListArgs=`echo -e "Action=DescribeDomainRecords\nDomainName=$Ali_Domain\nKeyWord=$Var_Record\nSearchMode=EXACT"`

    # 发送请求
    AliDnsSendRequest "$Var_ListArgs"
    # 检查结果
    if [ "$Var_ResponseCode" = "1" ]; then
        echo -e "${Msg_Error}[AliDNSRemove]解析记录($Var_Record.$Ali_Domain)查询失败!"
        exit 1
    else
        local Var_RecordCnt="`PharseJSON "${Var_RequestResult}" "TotalCount"`"
        if [ "$Var_RecordCnt" = "0" ]; then
            echo -e "${Msg_Warning}[AliDNSRemove]解析记录($Var_Record.$Ali_Domain)不存在!不需要删除"
            exit 1
        fi
    fi

    local Var_RecordId="`PharseJSON "${Var_RequestResult}" "RecordId"`"
    
    # 删除解析记录
    # +-----接口参数-------------------
    # | Action=DeleteDomainRecord
    # | RecordId=$Var_RecordId
    # +---------------------------------
    local Var_ModifyArgs=`echo -e "Action=DeleteDomainRecord\nRecordId=$Var_RecordId\n"`
    # 发送请求
    AliDnsSendRequest "$Var_ModifyArgs"
    if [ "$Var_ResponseCode" != "0" ]; then
        echo -e "${Msg_Error}[AliDNSRemove]解析记录($Var_Record.$Ali_Domain)删除失败!"
        exit 1
    else
        echo -e "${Msg_Success}[AliDNSRemove]解析记录($Var_Record.$Ali_Domain)删除成功!"
        exit 0
    fi
}

ShowVersion() {
    echo -e "阿里云DDNS解析脚本版"
    echo -e "Version: ${Version}, Last Update:${Update}"
}

ShowHelp() {
    echo -e "阿里云DDNS解析脚本版"
    echo -e "Version: ${Version}, Last Update:${Update}"
    echo -e "使用教程请参考：https://blog.lintian.co/2021/07/13/aliyunddns"
    echo -e "参数说明："
    echo -e "    -d, --domain         指定域名Ali_Domain,可以通过环境变量设置,两者都指定的时候脚本参数优先"
    echo -e "    -k, --key            指定Ali_Key,可以通过环境变量设置,两者都指定的时候脚本参数优先"
    echo -e "    -s, --secret         指定Ali_Secret,可以通过环境变量设置,两者都指定的时候脚本参数优先"
    echo -e "    -a, --add            增加解析记录"
    echo -e "        --record         记录名"
    echo -e "        --type           记录类型"
    echo -e "        --value          记录值"
    echo -e "    -m, --modify         修改解析记录,如果记录值不匹配则修改为指定值"
    echo -e "        --record         记录名"
    echo -e "        --value          记录值"
    echo -e "    -r, --remove         删除解析记录"
    echo -e "    -v, --version        版本信息"
    echo -e "    -h, --help           显示此帮助信息"
    echo -e ""
}

ParamCheck() {
    task_ck=`echo "$@" | grep -Eo '\-\-add|\-a | \-\-remove|\-r | \-\modify|\-m' | wc -l`

    if [ $task_ck -gt 1 ]; then
        # 只能指定一个操作
        echo -e "${Msg_Error}add,remove,modify操作只能同时指定一个"
        exit 1
    fi
}

parameters=`getopt -o d:k:s:amr:hv -l domain:,key:,secret:,add,modify,remove:,help,version,record:,type:,value: -n "$0" -- "$@"`

ParamCheck "$parameters"    # 参数检查
eval set -- "$parameters"   # 将$parameters设置为位置参数

while [ $# != 0 ]; do             # 循环解析位置参数
    case "$1" in
        -h|--help) ShowHelp; exit ;;
        -v|--version) ShowVersion; exit ;;
        -d|--domain) export Ali_Domain=$2; shift 2;;
        -k|--key) export Ali_Key=$2; shift 2 ;;
        -s|--secret) export Ali_Secret=$2; shift 2 ;;
        -a|--add) TASK="add"; shift ;;
        -m|--modify) TASK="modify"; shift ;;
        -r|--remove) TASK="remove"; Var_Record=$2; shift 2 ;;
        --record) Var_Record=$2; shift 2;;
        --type) Var_Type=$2; shift 2;;
        --value) Var_Value=$2; shift 2;;
        --)
            shift
            break ;;
    esac
done

case "$TASK" in
    add)
        AliDNSAdd
        exit ;;
    modify)
        AliDNSModify
        exit ;;
    remove)
        AliDNSRemove
        exit ;;
    *)
        echo -e "${Msg_Error}请指定操作!,或者-h,--help显示帮助信息"
        exit ;;
esac
