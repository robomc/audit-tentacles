# Configuration options
require 'ostruct'
$options = OpenStruct.new

$options.datastore = 1
$options.global_prefix = 'audit' # changing this will orphan hundreds of redis keys.
$options.page_delay = 0.1
$options.solr = 'http://search.tki.org.nz:8983/solr'
