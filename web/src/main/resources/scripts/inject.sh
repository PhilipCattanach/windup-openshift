#!/usr/bin/env bash
mkdir -p ${JBOSS_HOME}/standalone/log

echo "Installing keycloak server"
unzip -o -d ${JBOSS_HOME} /opt/tools/keycloak-server-overlay/keycloak-server-overlay-*.zip
sed -i 's#embed-server --server-config=standalone.xml#embed-server --server-config=standalone-openshift.xml#g' ${JBOSS_HOME}/bin/keycloak-install.cli

echo "Running keycloak server CLI script"
${JBOSS_HOME}/bin/jboss-cli.sh --echo-command --file=${JBOSS_HOME}/bin/keycloak-install.cli

echo "Installing keycloak client adapters"
unzip -o -d ${JBOSS_HOME} /opt/tools/keycloak-client-overlay/keycloak-wildfly-adapter-dist-*.zip

echo "Running local CLI script for configuring logging, queues, and keycloak client realm"
# Run our CLI script (logging and keycloak configuration)
${JBOSS_HOME}/bin/jboss-cli.sh --echo-command --file=${JBOSS_HOME}/standalone/configuration/setup.cli

echo "Running secure-deployments : secure-deployments.cli "
${JBOSS_HOME}/bin/jboss-cli.sh --echo-command --file=${JBOSS_HOME}/standalone/configuration/secure-deployments.cli

echo "Unzipping keycloak theme"
unzip -o -d ${JBOSS_HOME} /opt/tools/keycloak-theme/keycloak-theme.jar
cp ${JBOSS_HOME}/themes/mta/login/login_required.theme.properties ${JBOSS_HOME}/themes/mta/login/theme.properties

echo "Setting up keycloak server admin username/password"
${JBOSS_HOME}/bin/add-user-keycloak.sh --realm master --user admin --password password

echo "Setting up keycloak server mta default username/password"
${JBOSS_HOME}/bin/add-user-keycloak.sh --realm mta --user mta --password password --roles user

echo "Setting up JMS Password"
${JBOSS_HOME}/bin/add-user.sh -r ApplicationRealm -u jms-user -p gthudfal -g guest \
    -up ${JBOSS_HOME}/standalone/configuration/application-users.properties -gp \
    ${JBOSS_HOME}/standalone/configuration/application-roles.properties

# If there is no DB prefix mapping, then setup an internal H2 Instance
if [ -z ${DB_SERVICE_PREFIX_MAPPING+x} ]
then
    echo "Setting up embedded database, as the DB_SERVICE_PREFIX_MAPPING was not set"
    ${JBOSS_HOME}/bin/jboss-cli.sh --echo-command --file=${JBOSS_HOME}/standalone/configuration/db_h2.cli
fi

echo "Setting up as a master node"
${JBOSS_HOME}/bin/jboss-cli.sh --echo-command --file=${JBOSS_HOME}/standalone/configuration/master.cli

echo "Configuring keycloak and openshift layers"
sed -i -e 's#layers=keycloak#layers=keycloak,openshift#g' /opt/eap/modules/layers.conf

