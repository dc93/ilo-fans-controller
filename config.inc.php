<?php

/*
  ILO ACCESS CREDENTIALS
  --------------
  These are used to connect to the iLO
  interface and manage the fan speeds.
*/

$ILO_HOST = 'your-ilo-address';  // Ex. 192.168.1.69
$ILO_USERNAME = 'your-ilo-username';  // Ex. Administrator
$ILO_PASSWORD = 'your-ilo-password';  // Ex. AdministratorPassword1234

/*
  SSH KEY AUTHENTICATION (OPTIONAL)
  --------------
  If you prefer SSH key authentication instead of password,
  specify the paths to your public and private key files.
  Leave empty to use password authentication (default).

  Note: Password must still be provided as fallback, but won't
  be used if keys are successfully configured.
*/

$ILO_SSH_PUBLIC_KEY = '';   // Ex. /path/to/id_rsa.pub
$ILO_SSH_PRIVATE_KEY = '';  // Ex. /path/to/id_rsa
$ILO_SSH_KEY_PASSPHRASE = '';  // Leave empty if key has no passphrase

?>
