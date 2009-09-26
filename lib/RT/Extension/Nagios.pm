use warnings;
use strict;

package RT::Extension::Nagios;

=head1 NAME

RT::Extension::Nagios - Merge and resolve Nagios tickets

=cut

our $VERSION = '0.01';

1;

=head1 DESCRIPTION

Based on http://wiki.bestpractical.com/view/AutoCloseOnNagiosRecoveryMessages,
thanks, Todd Chapman!

Nagios( L<http://www.nagios.org> ) is a powerful monitoring system that enables
organizations to identify and resolve IT infrastructure problems before they
affect critical business processes.

Once you create Nagios tickets by piping Nagio's email notifications, this
extension helps you merge and resolve them.

We identify email by its subject, so please keep it as the
default one or alike, i.e. subject should pass the regex:

C<qr{(PROBLEM|RECOVERY) \s+ (Service|Host) \s+ Alert:
    \s+([^/]+)/(.*)\s+is\s+(\w+)}ix>

e.g.  "PROBLEM Service Alert: localhost/Root Partition is WARNING":

There are 5 useful parts in subject( we call them $1..$5 ):
PROBLEM, Service, localhost, Root Partition and WARNING

( Currently, we don't make use of $5 )

After the new ticket is created, the following is done:
find all the other active tickets in the same queue,
with the same values of $2, $3 and $4 in subject and merge all of them into
the new ticket.

If $1 is 'RECOVERY', resolve the new ticket

=head1 AUTHOR

sunnavy  C<< <sunnavy@bestpractical.com> >>

=head1 LICENCE AND COPYRIGHT

RT-Extension-Nagios is Copyright 2009 Best Practical Solutions, LLC.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

