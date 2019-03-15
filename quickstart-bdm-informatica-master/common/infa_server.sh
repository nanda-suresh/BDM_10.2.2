productType=$1
domain="InfaDomain"
nodeName="InfaNode"
oldDomainUser="Administrator"
oldDomainPwd="Administrator@1"
newDomainUser=$2
newDomainPwd=$3
dbUserName="admin"
dbUserPwd=$4
dbHost=$5
dbPort=1521
hdpClstrConfig=$6
loadEDCSample=$7
infaHome=/home/Informatica/Server
infaDownloads=/home/downloads
logFile=/home/Infa_OnceClick_Solution.log
ldmLoadLogFile=/home/ldm_load.log
hdpGatewayNodePubDns="None"
hdpAllNodePubDns="None,None"
ihsNodeCount=0
declare -a ihsNodeDnsArr

EMRID=$8
emrclusterrequired=$9
redshiftrequired=${10}
redshiftUserName=${11}
redshiftUserPwd=${12}
redshiftHost=${13}
redshiftPort=${14}
redshiftDb=${15}
s3bucketname=${16}
Subnet=${17}
Keypairname=${18}
region=${19}
ec2Role='EMR_EC2_DefaultRole'
serviceRole='EMR_DefaultRole'
securitygroup1=${20}
securitygroup2=${21}
InstanceRole=${22}
region1=${23}
redshiftNodeType=dc1.large
redshiftNoOfNodes=1

privateIp=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
privateDnsName=$(curl http://169.254.169.254/latest/meta-data/local-hostname)

if [ $productType = 'BDM' ]
then
	echo "Getting the EMR IP address and DNS Name"
	emripaddress=`aws emr list-instances --cluster-id $EMRID --instance-group-types "MASTER" --query 'Instances[*].{ID:PrivateDnsName}' --region $region1 | grep ID | cut -d ":" -f2 | sed 's/[ ,\"]//g'`
	emrip=`aws emr list-instances --cluster-id $EMRID --instance-group-types "MASTER" --query 'Instances[*].{ID:PrivateIpAddress}' --region $region1 | grep ID | cut -d ":" -f2 | sed 's/[ ,\"]//g'`

fi

tnsOraHostUpdate()
{
	export INFAINSTALL=/home/Informatica/Server
	export JAVA_HOME=/javasrc/java
	export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/lib/oracle/18.3/client64/bin:/usr/lib/oracle/18.3/client64/lib:${INFAINSTALL}/server/bin:${INFAINSTALL}/DataTransformation/bin:${INFAINSTALL}/services/shared/bin
	export PATH=${PATH}:/usr/lib/oracle/18.3/client64/bin:${JAVA_HOME}/bin:${INFAINSTALL}/server/bin:${INFAINSTALL}/DataTransformation/bin
	export ORACLE_HOME=/usr/lib/oracle/18.3/client64
	export TNS_ADMIN=/usr/lib/oracle/18.3/client64/lib/network/admin
	
	echo "updating tnsora" &>> $logFile
	TNSPATH="/usr/lib/oracle/18.3/client64/lib/network/admin/tnsnames.ora"
	chmod 777 $TNSPATH
	sed -i s/\<DB-HOST\>/${dbHost}/g $TNSPATH
	echo "tnsora updated with db hostname : ${dbHost}" &>> $logFile
}

updateDBpasswordsAndOptimize()
{
	echo "Optimizing Database..." &>> $logFile
	/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER domain_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
	/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER mrs_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile

	if [ $productType = 'BDM' ]
	then
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER bdm_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER wf_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER pw_user CASCADE" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER cms_user CASCADE" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER at_user CASCADE" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER dps_user CASCADE" &>> $logFile
	fi
	
	if [ $productType = 'EIC' ]
	then     
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER pw_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER cms_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "ALTER USER at_user IDENTIFIED BY ${dbUserPwd}" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER bdm_user CASCADE" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER dps_user CASCADE" &>> $logFile
		/javasrc/java/bin/java -jar ${infaDownloads}/oracleSQLRunner.jar ${dbHost} ${dbPort} INFADB admin ${dbUserPwd} "DROP USER wf_user CASCADE" &>> $logFile
	fi
}

hostProcess()
{
	if [ $productType = 'EIC' ]
	then
		dnsStr=${hdpClstrConfig}
		IFS=';' read -a arr <<< "$dnsStr"
		end=${#arr[@]}
		end1less=`expr $end - 1`
		ihsStrng=""
		hostEntry=""
		for ((i=0; i<$end; i++))
		do
			IFS=',' read -a arr2 <<< "${arr[i]}"
			ihsStrng="${ihsStrng}${arr2[1]}"
			if [[ $i -ne  ${end1less} ]]
			then
					ihsStrng="${ihsStrng},"
			fi
			hostEntry="${hostEntry}${arr2[0]} ${arr2[1]}\n"
		done
		IFS=',' read -a arr3 <<< "$ihsStrng"
		hdpGatewayNodePubDns=${arr3[0]}
		hdpAllNodePubDns=${ihsStrng}
		
		echo -e "Updating host entries for Informatica EIC domain..." &>> $logFile
		echo -e "${privateIp} ${privateDnsName}" >> /etc/hosts
		echo -e "$hostEntry" >> /etc/hosts
		
		echo -e "Updating IHS cluster node host entries..." &>> $logFile
		end2=${#arr3[@]}
		ihsNodeCount=end2
		ihsNodeDnsArr=arr3
		for ((i=0; i<$end2; i++))
		do
			sudo ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${arr3[i]} "sudo su -c 'printf \"${hostEntry}${privateIp} ${privateDnsName}\" >> /etc/hosts'"
			sudo ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${arr3[i]} "sudo su -c 'systemctl restart ntpd.service'"
		done
	fi
	
	if [ $productType = 'BDM' ]
	then
		echo -e "Updating host entries for Informatica BDM domain..." &>> $logFile
		echo -e "${privateIp} ${privateDnsName}" >> /etc/hosts
	fi
}

createRedshiftConnetion()
{
	#echo -e "\nRunning Redshift Connection Configuration...\n" &>> $logFile
	/javasrc/java/bin/java -jar ${infaDownloads}/RedshiftSQLFileRunner.jar $redshiftHost $redshiftPort $redshiftDb $redshiftUserName $redshiftUserPwd ${infaDownloads}/Redshift_SQL.sql &>> $logFile
	
	sleep 3
	
	echo -e "\nCreating Amazon Redshift Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'AMAZONREDSHIFT' -cn 'AWS_Redshift' -cid 'AWS_Redshift' -o "UserName='${redshiftUserName}' password='${redshiftUserPwd}' JDBCURL='jdbc:redshift://${redshiftHost}:${redshiftPort}/${redshiftDb}' NUMBEROFNODESINCLUSTER='${redshiftNoOfNodes}' CLUSTERNODETYPE='${redshiftNodeType}' schema='public'" &>> $logFile
}

createS3Connection()
{
	echo -e "\nCreating Amazon S3 Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'AMAZONS3' -cn 'AWS_S3' -cid 'AWS_S3' -o "regionName='${region}' FOLDERPATH='${s3bucketname}'" &>> $logFile
}

createBDMSampleConnection()
{
	echo -e "\nCreating BDM sample Oracle Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'JDBC' -cn 'BDMSampleConnection' -cun bdm_user -cpd $dbUserPwd -o "metadataConnString='jdbc:informatica:oracle://${dbHost}:${dbPort};SID=infadb' hadoopConnector='SQOOP_146' hadoopConnectorArgs='--connect jdbc:oracle:thin:@${dbHost}:${dbPort}:infadb' jdbcDriverClassName='com.informatica.jdbc.oracle.OracleDriver'" &>> $logFile
}

createWorkflowConnection()
{
	echo -e "\nCreating Workflow Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'oracle' -cn 'WorkflowConnection' -cun wf_user -cpd $dbUserPwd -o "CodePage=UTF-8 MetadataAccessConnectString='jdbc:informatica:oracle://${dbHost}:${dbPort};ServiceName=INFADB;MaxPooledStatements=20;CatalogOptions=0;BatchPerformanceWorkaround=true' DataAccessConnectString='infadb'" &>> $logFile
}

createProfilingWHConnection()
{
	echo -e "\nCreating Profiling Warehouse Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'oracle' -cn 'ProfilingWarehouseConnection' -cun pw_user -cpd $dbUserPwd -o "CodePage=UTF-8 MetadataAccessConnectString='jdbc:informatica:oracle://${dbHost}:${dbPort};ServiceName=INFADB;MaxPooledStatements=20;CatalogOptions=0;BatchPerformanceWorkaround=true' DataAccessConnectString='infadb'" &>> $logFile
}

createStagingDBConnection()
{
	echo -e "\nCreating Staging DB Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'oracle' -cn 'StagingDBConnection' -cun cms_user -cpd $dbUserPwd -o "CodePage=UTF-8 MetadataAccessConnectString='jdbc:informatica:oracle://${dbHost}:${dbPort};ServiceName=INFADB;MaxPooledStatements=20;CatalogOptions=0;BatchPerformanceWorkaround=true' DataAccessConnectString='infadb'" &>> $logFile
}

createExceptionAuditConnection()
{
	echo -e "\nCreating Exception Audit DB Connection...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct 'oracle' -cn 'exceptionAuditConnection' -cun at_user -cpd $dbUserPwd -o "CodePage=UTF-8 MetadataAccessConnectString='jdbc:informatica:oracle://${dbHost}:${dbPort};ServiceName=INFADB;MaxPooledStatements=20;CatalogOptions=0;BatchPerformanceWorkaround=true' DataAccessConnectString='infadb'" &>> $logFile
}

getPrivateIP()
{
	tempip=`egrep '[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}\.[[:digit:]]{1,3}' ~/yarn-site.xml`
	echo $tempip >> ~/temp.ip
	emrPvtIp=`sed -e 's/ //g' -e 's/<value>//g' -e 's/<\/value>//g' ~/temp.ip`
	cd ~/
	rm -rf *.xml
	rm -rf temp.ip
	echo "$emrPvtIp $emrPublicDns">>/etc/hosts
}

createHADOOPConnectioncco()
{
	hadoopout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct Hadoop -cn HADOOP_EMR -cid HADOOP_EMR -o "clusterConfigId='CCO_EMR' impersonationUserName='root'")
	if [[ ${hadoopout} =~ "Command ran successfully" ]]
	then
		echo -e "\nHadoop Connection - HADOOP_EMR is created successfully.\n" &>> $logFile
	else
		echo -e "\nEncountered an error while creating a Hadoop Connection.\n" &>> $logFile
		echo -e "${hadoopout}" &>> $logFile
	fi
}

createHADOOPConnectionautodeploy()
{
	hadoopout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct Hadoop -cn HADOOP_EMR_Autodeploy -cid HADOOP_EMR_Autodeploy -o "provisionConnectionId='EMR_Autodeploy' impersonationUserName='root'")
	if [[ ${hadoopout} =~ "Command ran successfully" ]]
	then
		echo -e "\nHadoop Connection - HADOOP_EMR is created successfully.\n" &>> $logFile
	else
		echo -e "\nEncountered an error while creating a Hadoop Connection.\n" &>> $logFile
		echo -e "${hadoopout}" &>> $logFile
	fi
}

createAutodeployConnection()
{
	hadoopout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -ct AWSCLOUDPROVISIONINGCONNECTION -cn EMR_Autodeploy -cid Autodeploy_EMR -o "ec2KeyPair="$Keypairname" ec2Role='EMR_EC2_DefaultRole' ec2SubnetName="$Subnet" region="$region1" serviceRole='EMR_DefaultRole'")
	if [[ ${hadoopout} =~ "Command ran successfully" ]]
	then
		echo -e "\EMR Autodeploy Connection - EMR_Autodeploy is created successfully.\n" &>> $logFile
	else
		echo -e "\nEncountered an error while creating a EMR_Autodeploy Connection.\n" &>> $logFile
		echo -e "${hadoopout}" &>> $logFile
	fi
	createHADOOPConnectionautodeploy
}

createHDFSConnection()
{
	hdfsout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -cn HDFS_EMR -cid HDFS_EMR -ct HadoopFileSystem -o  "NameNodeURL=hdfs://"$emrip":8020/ USERNAME='hdfs' clusterConfigId='CCO_EMR'")

	if [[ ${hdfsout} =~ "Command ran successfully" ]]
	then
		echo -e "\nHDFS Connection - HDFS_EMR is created successfully." &>> $logFile
	else
		echo -e "\nEncountered an error while creating a HDFS Connection.\n" &>> $logFile
		echo -e "${hdfsout}" &>> $logFile
	fi
}

createHBASEConnection()
{
	hbaseout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -cn HBASE_EMR -cid HBASE_EMR -ct HBase -o  clusterConfigId='CCO_EMR')
	if [[ ${hbaseout} =~ "Command ran successfully" ]]
	then
		echo -e "\nHbase Connection - HBASE_EMR is created successfully." &>> $logFile
	else
		echo -e "\nEncountered an error while creating a Hbase Connection.\n" &>> $logFile
		echo -e "${hbaseout}">> "$oneclicksolutionlog"
	fi
}

createHIVEConnection()
{
	hiveout=$($infaHome/isp/bin/infacmd.sh  createConnection -dn $domain -un $newDomainUser -pd $newDomainPwd -cn HIVE_EMR -cid HIVE_EMR -ct Hive -o "clusterConfigId='CCO_EMR' bypassHiveJDBCServer='false' metadataConnString='jdbc:hive2://"$emrip":10000/' connectString='jdbc:hive2://"$emrip":10000/' enableQuotes='false'")

	if [[ ${hiveout} =~ "Command ran successfully" ]]
	then
		echo -e "\nHive Connection - HIVE_EMR is created successfully." &>> $logFile
	else
		echo -e "\nEncountered an error while creating a Hive Connection." &>> $logFile
		echo -e "${hiveout}">> "$oneclicksolutionlog"
	fi
}

createCCOConnection()
{
	ccopass=1
	zipcreation=1
	
	cd $infaDownloads
	unzip xmlfiles.zip
	mv ${infaDownloads}/home/hadoop/xmls/* ~/
	rm -rf home
	cd ~/
	zip -r hadoop.zip *.xml
	listitems=$(ls | grep hadoop)
	if [[ $listitems =~ "hadoop.zip" ]]
	then
		echo "zip created"
		zipcreation=0
		mv hadoop.zip /home/ec2-user
	else
		zipcreation=1
		echo -e "\nEncountered an error with zip creation for CCO.\n" &>> $logFile
		echo -e "\nSkipping CCO and related connection creation.\n" &>> $logFile
	fi
	
	if [ "$zipcreation" -eq 0 ]
	then
		cco_output=$($infaHome/isp/bin/infacmd.sh  cluster createConfiguration -dn $domain -un $newDomainUser -pd $newDomainPwd -cn CCO_EMR -path /home/ec2-user/hadoop.zip -dt EMR)
		if [[ ${cco_output} =~ "Command ran successfully" ]]
		then
			ccopass=0
			echo -e "\nCluster Configuration Object - CCO_EMR is created successfully.\n" &>> $logFile
		else
			ccopass=1
			echo -e "\nEncountered an error while creating a Cluster Configuration Object.\n" &>> $logFile
			echo -e "${cco_output}" &>> $logFile
			echo -e "\nCluster related Connections cannot be created without a CCO." &>> $logFile
		fi
	fi
	
	if [ "$ccopass" -eq 0 ]
	then
		getPrivateIP
		createHADOOPConnectioncco
		createHBASEConnection
		createHDFSConnection
		createHIVEConnection
	fi
}	

createCCOConnectionEMR()
{
	echo "Getting the EMR IP address and DNS Name"
	emripaddress=`aws emr list-instances --cluster-id $EMRID --instance-group-types "MASTER" --query 'Instances[*].{ID:PrivateDnsName}' --region $region1 | grep ID | cut -d ":" -f2 | sed 's/[ ,\"]//g'`
	emrip=`aws emr list-instances --cluster-id $EMRID --instance-group-types "MASTER" --query 'Instances[*].{ID:PrivateIpAddress}' --region $region1 | grep ID | cut -d ":" -f2 | sed 's/[ ,\"]//g'`
	echo "Preparing the zip file for creating the CCO"
	unzip /home/downloads/hadoop.zip
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/core-site.xml
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/yarn-site.xml
	sed -i -e 's/172.31.30.90/'$emrip'/g' /home/ec2-user/hadoop/yarn-site.xml
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/mapred-site.xml
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/hive-site.xml
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/hdfs-site.xml
	sed -i -e 's/ip-172-31-30-90.us-west-2.compute.internal/'$emripaddress'/g' /home/ec2-user/hadoop/hbase-site.xml
	zip -r /home/ec2-user/hadoop.zip /home/ec2-user/hadoop
	echo "Creating the CCO"
	cco_output=$($infaHome/isp/bin/infacmd.sh  cluster createConfiguration -dn $domain -un $newDomainUser -pd $newDomainPwd -cn CCO_EMR -path /home/ec2-user/hadoop.zip -dt EMR)
	if [[ ${cco_output} =~ "Command ran successfully" ]]
		then
			ccopass=0
			echo -e "\nCluster Configuration Object - CCO_EMR is created successfully.\n" &>> $logFile
		else
			ccopass=1
			echo -e "\nEncountered an error while creating a Cluster Configuration Object.\n" &>> $logFile
			echo -e "${cco_output}" &>> $logFile
			echo -e "\nCluster related Connections cannot be created without a CCO." &>> $logFile
	fi
	createHADOOPConnectioncco
	createHBASEConnection
	createHDFSConnection
	createHIVEConnection
}

updateDomain()
{
	echo -e "\nConfiguring Domain...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infasetup.sh updateGatewayNode -da ${dbHost}:${dbPort} -du domain_user -dp ${dbUserPwd} -dt ORACLE -ds INFADB -na ${privateDnsName}:6005 -resetHostPort true &>> $logFile

	echo -e "\nBringing Domain up...\n" &>> $logFile
	sh ${infaHome}/tomcat/bin/infaservice.sh startup  &>> $logFile
	sleep 120
	
	echo -e "\nChecking Admin Console is up or Not...\n" &>> $logFile
	status=$(${infaHome}/isp/bin/infacmd.sh  ping -dn $domain -sn _AdminConsole -re 360)
	chkCount=0
	while [[ $status != *"Command ran successfully"* ]]
	do
		if [ $chkCount -eq 20 ]
		then
			echo -e "\nDomain is not up. Something went wrong. Exiting..." &>> $logFile
			exit 1
		fi
		expr `chkCount = ${chkCount} + 1`
		sleep 10
		status=$(${infaHome}/isp/bin/infacmd.sh  ping -dn $domain -sn _AdminConsole -re 360)
	done
	
	echo -e "\nConfiguring Administrator user...\n" &>> $logFile
	newDomainUserUppercase=$(echo $newDomainUser | tr 'a-z' 'A-Z')
	if [[ $newDomainUserUppercase == "ADMINISTRATOR" ]] && [[ $newDomainPwd == "Administrator@1" ]]
	then
	echo "No Change required for Administrator user" &>> $logFile
	elif [[ $newDomainUserUppercase == "ADMINISTRATOR"  ]]
	then
		echo -e "Changing password for Administrator user" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh  resetPassword -dn $domain -un $oldDomainUser -pd $oldDomainPwd -ru $oldDomainUser -rp $newDomainPwd &>> $logFile
	else
		echo -e "Creating new Administrator user - $newDomainUser" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh createUser -dn $domain -un $oldDomainUser -pd $oldDomainPwd -nu $newDomainUser -np $newDomainPwd -nf $newDomainUser &>> $logFile
		
		echo -e "Assigning roles and groups to user - $newDomainUser" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh assignRoleTouser -dn $domain -un $oldDomainUser -pd $oldDomainPwd -eu $newDomainUser -rn Administrator -sn $domain &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh addUserToGroup -dn $domain -un $oldDomainUser -pd $oldDomainPwd -eu $newDomainUser -gn Administrator &>> $logFile
		
		echo -e  "Changing Administrator password to new password" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh  resetPassword -dn $domain -un $oldDomainUser -pd $oldDomainPwd -ru $oldDomainUser -rp $newDomainPwd &>> $logFile
	fi
}

addLicense()
{
	echo -e "\nAdding License to Domain...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh addLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -lf ${infaDownloads}/License.key &>> $logFile
	
	shred --remove ${infaDownloads}/License.key
}

enableMRS()
{
	echo -e "\nApplying License to Model Repository Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Model_Repository_Service' &>> $logFile
	
	echo -e "\nConfiguring Model Repository Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh mrs updateServiceOptions -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Model_Repository_Service -o " PERSISTENCE_DB.Password=${dbUserPwd} PERSISTENCE_DB.JDBCConnectString=jdbc:informatica:oracle://${dbHost}:${dbPort};ServiceName=INFADB;MaxPooledStatements=20;CatalogOptions=0;BatchPerformanceWorkaround=true" &>> $logFile
	
	echo -e "\nEnabling Model Repository Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Model_Repository_Service &>> $logFile
	
	if [ $loadEDCSample = 'Yes' ]
	then
		echo -e "\nMaking MRS ready for sample content loading...\n" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh mrs deleteContents -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Model_Repository_Service &>> $logFile
		
		echo -e "\nLoading MRS sample contents...\n" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh mrs restoreContents -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Model_Repository_Service -if ${infaDownloads}/mrsBackup1022.mrep &>> $logFile
	fi
}

enableDIS()
{
	echo -e "\nApplying License to Data Integration Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Data_Integration_Service' &>> $logFile
	
	if [ $productType = 'BDM' ]
	then
		hdpDisDir="${infaHome}/services/shared/hadoop/EMR_5.16"
	else
		hdpDisDir="${infaHome}/services/shared/hadoop/HDP_2.6"
	fi
	
	echo -e "\nConfiguring Data Integration Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh dis updateServiceOptions -dn $domain -un $newDomainUser -pd $newDomainPwd -sn 'Data_Integration_Service' -o "RepositoryOptions.RepositoryUserName='${newDomainUser}' RepositoryOptions.RepositoryPassword='${newDomainPwd}' ExecutionOptions.JdkHomePath='/javasrc/java' ExecutionOptions.DisHadoopDistributionDir='${hdpDisDir}'" &>> $logFile
	
	echo -e "\nEnabling Data Integration Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Data_Integration_Service &>> $logFile
}

enableCMS()
{
	echo -e "\nCreating Content Management Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh cms createService -dn $domain -un $newDomainUser -pd $newDomainPwd -nn $nodeName -sn 'Content_Management_Service' -ds Data_Integration_Service -HttpPort 8105 -rs Model_Repository_Service -rdl StagingDBConnection -rsu $newDomainUser -rsp $newDomainPwd &>> $logFile
	
	echo -e "\nApplying License to Content Management Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Content_Management_Service' &>> $logFile
	
	echo -e "\nEnabling Content Management Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Content_Management_Service &>> $logFile
}

enableMASS()
{
	echo -e "\nCreating Metadata Accesss Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh mas createService -dn $domain -un $newDomainUser -pd $newDomainPwd -nn $nodeName -sn 'Metadata_Access_Service' -hp http -pt 7080 &>> $logFile
	echo -e "\nApplying License to Metadata Accesss Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Metadata_Access_Service' &>> $logFile
	echo -e "\nEnabling Metadata Accesss Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Metadata_Access_Service &>> $logFile
}

enableIHS()
{
	echo -e "\nSyncing NTP on IHS cluster nodes...\n" &>> $logFile
	for ((i=0; i<$ihsNodeCount; i++))
	do
		sudo ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ${ihsNodeDnsArr[i]} "sudo su -c 'systemctl restart ntpd.service'"
	done
		
	echo -e "\nCreating Informatica Hadoop Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh ihs createservice -dn $domain -un $newDomainUser -pd $newDomainPwd -nn $nodeName -sn 'Informatica_Hadoop_Service' -p 8088 -hgh ${hdpGatewayNodePubDns} -hgp 8080 -hn ${hdpAllNodePubDns} -gu root -krb false -dssl false -opwd false -oo "IcsCustomOptions.ihssecurity.ssl.disable=true" &>> $logFile
	
	echo -e "\nApplying License to Informatica Hadoop Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Informatica_Hadoop_Service' &>> $logFile
	
	echo -e "\nEnabling Informatica Hadoop Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Informatica_Hadoop_Service &>> $logFile
}

enableLDM()
{
	echo -e "\nCreating Catalog Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh LDM createService -dn $domain -un $newDomainUser -pd $newDomainPwd -nn $nodeName -sn 'Catalog_Service' -mrs 'Model_Repository_Service' -mrsun ${newDomainUser} -mrspd ${newDomainPwd} -p 8090 -ise false -ihsn 'Informatica_Hadoop_Service' -isc false -cne  -lt low &>> $logFile
	
	echo -e "\nApplying License to Catalog Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Catalog_Service' &>> $logFile
	
	if [ $loadEDCSample = 'Yes' ]
	then
		echo -e "\nLoading LDM sample contents...\n" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh ldm restoreContents -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Catalog_Service -if ${infaDownloads}/ldmBackup1022.zip &>> $ldmLoadLogFile
		ldmLoadStatus=$(tail $ldmLoadLogFile)
		if [[ $ldmLoadStatus != *"Command ran successfully"* ]]
		then
			echo -e "\nLDM sample load failed check for error in file $ldmLoadLogFile...\n" &>> $logFile
		else
			echo -e "\nLDM sample load completed...\n" &>> $logFile
		fi
	fi
	
	echo -e "\nEnabling Catalog Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Catalog_Service &>> $logFile
}

checkAndReEnableLDM()
{
	echo -e "\nChecking Catalog Service status...\n" &>> $logFile
	ldmStatus=$(${infaHome}/isp/bin/infacmd.sh ping -dn $domain -sn Catalog_Service)
	if [[ $ldmStatus != *"Command ran successfully"* ]]
	then
		echo -e "\nDisabling Catalog Service...\n" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh disableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Catalog_Service -mo ABORT &>> $logFile
		sleep 10
		echo $'for x in $(yarn application -list  | awk \'NR > 2 { print $1 }\'); do yarn application -kill $x; done' > ${infaDownloads}/ldmAppkill.sh
		ssh root@${hdpGatewayNodePubDns} < ${infaDownloads}/ldmAppkill.sh
		sleep 10
		echo -e "\nRe-enabling Catalog Service...\n" &>> $logFile
		sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Catalog_Service &>> $logFile
	fi
}

enableAT()
{
	echo -e "\nCreating Analyst Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh as createService -dn $domain -un $newDomainUser -pd $newDomainPwd -nn $nodeName -sn 'Analyst_Service' -rs Model_Repository_Service -ds Data_Integration_Service -ffl /tmp -cs Catalog_Service -csau ${newDomainUser} -csap ${newDomainPwd} -au ${newDomainUser} -ap ${newDomainPwd} -bgefd /tmp -HttpPort 6805 &>> $logFile
	
	echo -e "\nApplying License to Analyst Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh assignLicense -dn $domain -un $newDomainUser -pd $newDomainPwd -ln License -sn 'Analyst_Service' &>> $logFile
	
	echo -e "\nModifying to Analyst Service properties...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh as updateServiceOptions -dn $domain -un $newDomainUser -pd $newDomainPwd -sn 'Analyst_Service' -o "HumanTaskDataIntegrationService.humanTaskDsServiceName=Data_Integration_Service HumanTaskDataIntegrationService.exceptionDbName=exceptionAuditConnection" &>> $logFile
	
	echo -e "\nEnabling Analyst Service...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh enableService -dn $domain -un $newDomainUser -pd $newDomainPwd -sn Analyst_Service &>> $logFile
	
	echo -e "\nCreating Analyst Service Audit table contents...\n" &>> $logFile
	sh ${infaHome}/isp/bin/infacmd.sh as createExceptionAuditTables -dn $domain -un $newDomainUser -pd $newDomainPwd -sn 'Analyst_Service' &>> $logFile
}

createConnections()
{
	if [ $productType = 'EIC' ]
	then
		createProfilingWHConnection
		createStagingDBConnection
		createExceptionAuditConnection
	fi
	
	if [ $productType = 'BDM' ]
	then
		createBDMSampleConnection
		createWorkflowConnection
		createProfilingWHConnection
		createS3Connection
		if [[ $redshiftrequired == 'Required' ]]
		then
			createRedshiftConnetion
		fi
		if [[ $emrclusterrequired = 'Yes' ]]
		then
			createAutodeployConnection
		else
		    createCCOConnectionEMR
		fi
	fi
}

enableServices()
{
	enableMRS
	enableDIS
	if [ $productType = 'BDM' ]
	then
	    enableMASS
	fi
	
	if [ $productType = 'EIC' ]
	then
		enableCMS
		enableIHS
		sleep 15
		enableLDM
		sleep 5
		checkAndReEnableLDM
		sleep 5
		enableAT
	fi
}

if [ $productType = 'BDM' ]
then
	echo -e "\nStaring Configuration for BDM...\n" &>> $logFile
else
	echo -e "\nStaring Configuration for EIC...\n" &>> $logFile
fi

ulimit -n 50000
ulimit -u 50000

tnsOraHostUpdate
updateDBpasswordsAndOptimize
hostProcess
updateDomain
addLicense
createConnections
enableServices

if [ $productType = 'BDM' ]
then
	echo -e "\nConfiguration for BDM finished...\n" &>> $logFile
else
	echo -e "\nConfiguration for EIC finished...\n" &>> $logFile
fi
