echo -n "Status of your RPort server: "
if pgrep rportd>/dev/null 2>&1;then
  echo "Running :-)"
else
  echo "NOT RUNNING"
  echo "Check the logs in /var/log/rport/rportd.log"
  false
fi
SUMMARY="/root/rportd-installation.txt"
echo "RPortd installed $(date)
Admin URL: https://${FQDN}:${API_PORT}
User:      admin
Password:  $ADMIN_PASSWD
${TWO_FA_MSG}
">$SUMMARY
echo "------------------------------------------------------------------------------"
echo " TATAA!!  All finished "
echo ""
sleep 0.3
echo " ----> Let's get started <----"
echo " Point your browser to https://${FQDN}:${API_PORT} "
echo " Login with:"
echo "    User     = admin"
echo "    Password = $ADMIN_PASSWD"
echo ""
echo " ${TWO_FA_MSG}"
echo "------------------------------------------------------------------------------"
