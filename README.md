msktutil_script
================

Scripts to back-up and replace multiple files on a RHEL5 or RHEL5-clone server
so that it will use Kerberos authentication from a Windows 2003 RC2 or 2008 R2
Active Directory Domain.

The script leverages msktutil to create and manage the schema objects in Active
 Directory.

The script requires that you have an account in the Active Directory domain 
with the administrative rigth to join servers to the domain and to manage 
servers objects.  In other words, a Domain Administrator account.

This script does *not* create new or modify existing users with the schema 
attributes and values required to properly authenticate from the Linux server 
to Active Directory.

running msktutil_core
================