use inc::Module::Install;
RTx('RT-Extension-Nagios');
all_from('lib/RT/Extension/Nagios.pm');
&WriteAll;
