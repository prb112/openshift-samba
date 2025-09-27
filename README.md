This is a for deploying Samba 4 on OpenShift. It uses a multi-stage build to create a minimal image that includes only the necessary components to run Samba 4. The chart also includes a script to enable the Docker registry and push the image to the OpenShift registry.

This project is unsupported by Red Hat and IBM.

References and Credit go to:

https://github.com/dperson/samba
https://www.samba.org
https://github.com/iMartyn/helm-samba4/blob/master/samba4/conf/smb.conf