#!/bin/bash

# ========================================
# TOKEN DO METADATA SERVICE (IMDSv2)
# ========================================

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

# ========================================
# METADADOS DA INSTÂNCIA
# ========================================

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
-s http://169.254.169.254/latest/meta-data/instance-id)

AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
-s http://169.254.169.254/latest/meta-data/placement/availability-zone)

REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
-s http://169.254.169.254/latest/meta-data/placement/region)

# ========================================
# ESTADO REAL DA INSTÂNCIA
# ========================================

INSTANCE_STATE=$(aws ec2 describe-instances \
--instance-ids $INSTANCE_ID \
--region $REGION \
--query "Reservations[0].Instances[0].State.Name" \
--output text 2>/dev/null)

# ========================================
# CLOUDWATCH ALARMS
# ========================================

CPU_ALARM=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighCPUUsage'].StateValue" \
--output text 2>/dev/null)

ERROR_ALARM=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighErrorCount'].StateValue" \
--output text 2>/dev/null)

# ========================================
# TRATAMENTO DE ALARMES NÃO EXISTENTES
# ========================================

if [ -z "$CPU_ALARM" ]; then
CPU_ALARM="not_created"
fi

if [ -z "$ERROR_ALARM" ]; then
ERROR_ALARM="not_created"
fi

# ========================================
# VALIDAR SE O ALARME EXISTE
# ========================================

ALARM_EXISTS=$(aws cloudwatch describe-alarms \
--region $REGION \
--query "MetricAlarms[?AlarmName=='HighCPUUsage'].AlarmName" \
--output text 2>/dev/null)

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
# SIMULAÇÃO DA AÇÃO CORRETIVA
# (se CPU alarmar, considerar stopped)
# ========================================

if [ "$CPU_ALARM" == "ALARM" ]; then
INSTANCE_STATE="stopped"
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