#!/bin/bash

# ========================================
# METADADOS DA INSTÂNCIA
# ========================================

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

REGION=${AZ::-1}


# ========================================
# ESTADO DA INSTÂNCIA
# ========================================

INSTANCE_STATE=$(aws ec2 describe-instances \
--instance-ids $INSTANCE_ID \
--region $REGION \
--query "Reservations[0].Instances[0].State.Name" \
--output text)


# ========================================
# CLOUDWATCH ALARMS
# ========================================

CPU_ALARM=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighCPUUsage'].StateValue" \
--output text)

ERROR_ALARM=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighErrorCount'].StateValue" \
--output text)


# ========================================
# VALIDAR SE O ALARME EXISTE
# ========================================

ALARM_EXISTS=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighCPUUsage'].AlarmName" \
--output text)

if [ -z "$ALARM_EXISTS" ]; then
ALARM_VALIDATION="not_found"
else
ALARM_VALIDATION="found"
fi


# ========================================
# STATUS SNS
# ========================================

SNS_STATUS="Aguardando eventos"

if [ "$CPU_ALARM" == "ALARM" ] || [ "$ERROR_ALARM" == "ALARM" ]; then
SNS_STATUS="Notificação enviada"
fi


# ========================================
# GERAR JSON PARA DASHBOARD
# ========================================

cat <<EOF > /var/www/html/status.json
{
    "instanceId": "$INSTANCE_ID",
    "region": "$REGION",
    "az": "$AZ",
    "state": "$INSTANCE_STATE",

    "cpuAlarm": "$CPU_ALARM",
    "errorAlarm": "$ERROR_ALARM",

    "alarmValidation": "$ALARM_VALIDATION",

    "snsStatus": "$SNS_STATUS",

    "lastUpdate": "$(date)"
}
EOF