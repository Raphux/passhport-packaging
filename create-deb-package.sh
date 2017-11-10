#!/bin/bash
VERSION=$1
TMP_DIR=`mktemp -d`
BUILD_DIR="${TMP_DIR}/passhport-${VERSION}"
mkdir -p "${BUILD_DIR}/var/lib/passhport/"
mkdir -p "${BUILD_DIR}/var/lib/passhport/certs"
mkdir -p "${BUILD_DIR}/var/lib/passhport/db"
mkdir -p "${BUILD_DIR}/var/lib/passhport/.ssh/"
mkdir -p "${BUILD_DIR}/var/lib/passhport/.access_passwd/"
mkdir -p "${BUILD_DIR}/var/log/passhport/"
mkdir -p "${BUILD_DIR}/etc/passhport/"
mkdir -p "${BUILD_DIR}/etc/bash_completion.d/"
mkdir -p "${BUILD_DIR}/usr/bin/"
mkdir -p "${BUILD_DIR}/usr/sbin/"
mkdir -p "${BUILD_DIR}/usr/share/passhport"
mkdir -p "${BUILD_DIR}/lib/systemd/system/"
cp -r deb-files/debian "${BUILD_DIR}/DEBIAN"

# Get the source from github
cd "${TMP_DIR}"
git clone http://github.com/raphux/passhport.git

cp -r "${TMP_DIR}/passhport/passhportd" "${BUILD_DIR}/var/lib/passhport/"
cp -r "${TMP_DIR}/passhport/passhport-admin" "${BUILD_DIR}/var/lib/passhport/"
cp -r "${TMP_DIR}/passhport/passhport" "${BUILD_DIR}/var/lib/passhport/"

virtualenv -p python3 ${BUILD_DIR}/var/lib/passhport/python-run-env
${BUILD_DIR}/var/lib/passhport/python-run-env/bin/pip install pymysql sqlalchemy-migrate flask-migrate requests docopt configparser tabulate flask-login ldap3

cp "${TMP_DIR}/passhport/passhportd/passhportd.ini" "${BUILD_DIR}/etc/passhport/"
cp "${TMP_DIR}/passhport/passhport/passhport.ini" "${BUILD_DIR}/etc/passhport/"
cp "${TMP_DIR}/passhport/passhport-admin/passhport-admin.ini" "${BUILD_DIR}/etc/passhport/"
cp "${TMP_DIR}/passhport/passhportd/passhportd.ini" "${BUILD_DIR}/etc/passhport/"
cp "${TMP_DIR}/passhport/tools/passhportd.service" "${BUILD_DIR}/lib/systemd/system/"

sed -i -e 's#SSH_KEY_FILE\s*=.*#SSH_KEY_FILE        = /var/lib/passhport/.ssh/authorized_keys#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#PASSHPORT_PATH\s*=.*#PASSHPORT_PATH        = /var/lib/passhport/passhport/passhport#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#PYTHON_PATH\s*=.*#PYTHON_PATH        = /var/lib/passhport/python-run-env/bin/python3#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#SSL_CERTIFICAT\s*=.*#SSL_CERTIFICAT        = /var/lib/passhport/certs/cert.pem#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#SSL_KEY\s*=.*#SSL_KEY        = /var/lib/passhport/certs/key.pem#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#SQLALCHEMY_DATABASE_DIR\s*=.*#SQLALCHEMY_DATABASE_DIR        = /var/lib/passhport/#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#LISTENING_IP\s*=.*#LISTENING_IP = 0.0.0.0#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#SQLALCHEMY_MIGRATE_REPO\s*=.*#SQLALCHEMY_MIGRATE_REPO        = /var/lib/passhport/db/db_repository#' "${BUILD_DIR}/etc/passhport/passhportd.ini"
sed -i -e 's#SQLALCHEMY_DATABASE_URI\s*=.*#SQLALCHEMY_DATABASE_URI        = sqlite:////var/lib/passhport/db/app.db#' "${BUILD_DIR}/etc/passhport/passhportd.ini"

sed -i -e "s#PASSHPORTD_HOSTNAME\s*=.*#PASSHPORTD_HOSTNAME = localhost#" "${BUILD_DIR}/etc/passhport/passhport-admin.ini"
sed -i -e "s#SSL_CERTIFICAT\s*=.*#SSL_CERTIFICAT = /var/lib/passhport/certs/cert.pem#" "${BUILD_DIR}/etc/passhport/passhport-admin.ini"
sed -i -e "s#SSL_KEY\s*=.*#SSL_KEY = /var/lib/passhport/certs/key.pem#" "${BUILD_DIR}/etc/passhport/passhport-admin.ini"

sed -i -e "s#PASSHPORTD_HOSTNAME\s*=.*#PASSHPORTD_HOSTNAME = localhost#" "${BUILD_DIR}/etc/passhport/passhport.ini"
sed -i -e "s#SSL_CERTIFICAT\s*=.*#SSL_CERTIFICAT = /var/lib/passhport/certs/cert.pem#" "${BUILD_DIR}/etc/passhport/passhport.ini"
sed -i -e "s#SSL_KEY\s*=.*#SSL_KEY = /var/lib/passhport/certs/key.pem#" "${BUILD_DIR}/etc/passhport/passhport.ini"
sed -i -e "s#PWD_FILE_DIR\s*=.*#PWD_FILE_DIR = /var/lib/passhport/.access_passwd#" "${BUILD_DIR}/etc/passhport/passhport.ini"

sed -i -e "s#ExecStart=.*#ExecStart=/var/lib/passhport/python-run-env/bin/python /var/lib/passhport/passhportd/passhportd#" "${BUILD_DIR}/lib/systemd/system/passhportd.service"

echo "#!/bin/bash
# Launch the passhport-admin in the virtualenv
/var/lib/passhport/python-run-env/bin/python /var/lib/passhport/passhport-admin/passhport-admin \"\$@\"" > "${BUILD_DIR}/usr/bin/passhport-admin"


echo "#!/bin/bash
# Launch the passhportd in the virtualenv
nohup /var/lib/passhport/python-run-env/bin/python /var/lib/passhport/passhportd/passhportd >> /var/log/passhport/passhportd 2>&1 &" > "${BUILD_DIR}/usr/sbin/passhportd"

chmod 755 "${BUILD_DIR}/usr/sbin/passhportd" "${BUILD_DIR}/usr/bin/passhport-admin"

cp "${TMP_DIR}/passhport/tools/openssl-for-passhportd.cnf" "${BUILD_DIR}/usr/share/passhport/openssl.cnf"


cp "${TMP_DIR}/passhport/tools/passhport-admin.bash_completion" "${BUILD_DIR}/etc/bash_completion.d/passhport-admin"

sed -i -e "s/VERSION/${VERSION}/" "${BUILD_DIR}/DEBIAN/control"

dpkg-deb --build passhport-${VERSION}

echo "Remove temporary build dir (${BUILD_DIR})? y/n"
read ANSWER
if [ "${ANSWER}" == "Y" ] || [ "${ANSWER}" == "y" ]
then
	rm -rf "${BUILD_DIR}"
fi
