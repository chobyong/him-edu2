<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'memcache.distributed' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' => 
  array (
    'host' => 'redis',
    'password' => '',
    'port' => 6379,
  ),
  'upgrade.disable-web' => true,
  'instanceid' => 'ocxyk70az8r0',
  'passwordsalt' => 'SU3qKGx5/bKtSYBTsPksj2Oyxao5Pw',
  'secret' => 'j2cUiuW8L6INM/AZacDZfQO1m9Y9u5Wi+Q+03cPw82NNwv/Y',
  'trusted_domains' => 
  array (
    0 => 'nextcloud.him-edu.local',
    1 => '10.42.0.1:8081',
    2 => '10.0.1.142:8081',
  ),
  //'overwritehost' => '10.42.0.1:8081',
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '32.0.3.2',
  //'overwrite.cli.url' => 'http://10.42.0.1:8081',
  'dbname' => 'nextcloud',
  'dbhost' => 'nextclouddb',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => 'dbpassword',
  'installed' => true,
);
