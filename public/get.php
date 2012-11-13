<?php
$target_url = $_GET['url'];
 
//Find the root url of the target url for <base>
$array_url = explode(".", $target_url);
$sub_domain = $array_url[0];
 
//Strip anything after .com/.net/.info/etc
$top_level_domain = substr($array_url[2], 0, 4);
 
//make sure we have the correct 3 or 4 characters
if (substr($top_level_domain, 3, 4) == "/" || substr($top_level_domain, 3, 4) == ""){
    $top_level_domain = substr($top_level_domain, 0, 3);
}
//build the root url
$root_url = $sub_domain.".".$array_url[1].".".$top_level_domain;
 
//Get the html from the external site.
$html = file_get_contents($target_url) or die($target_url." Failed");

//Inject html <base> as the first element of <head>.
$html = str_ireplace("<head>", "<head><base href=\"$root_url/\" />", $html);
 
//Inject javascript as the last element of <head>.
$html = str_ireplace("</head>", "<script type=\"text/javascript\" src=\"http://io.holalabs.com/iopanel/selector.js\"></script> </head>", $html);

$html = str_ireplace("</head>", "<style>.holalabsrulz {background-color: rgba(0, 60, 100, 0.2) !important; cursor:crosshair !important;}</style>", $html);

//Ship it.
echo $html;

?>
