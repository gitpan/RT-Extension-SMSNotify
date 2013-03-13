#!/usr/bin/perl

package RT::Extension::SMSNotify;

=pod

=head1 NAME

RT::Extension::SMSNotify - Send SMS notifications from RT via SMS::Send

=head1 SYNOPSIS

You don't generally use this module directly from your own code, it's an RT
extension. See L</"CONFIGURATION">

=head1 DESCRIPTION

Use RT::Extension::SMSNotify to send text message notifications to mobile
phones when events occur in RT, or via RT Crontool to do time-based alerting
for things like SLA warnings.

Useful in conjunction with the L<RT::Extension::SLA> module.

SMSes are sent using the L<SMS::Send> module; this has been tested with
L<SMS::Send::RedOxygen>. You will need an SMS::Send driver module installed to
use the SMSNotify extension. Writing them is easy if you can't find one for
your provider.

B<Most SMS providers only offer asynchronous non-guranteed delivery> and
there's no provision for asynchronous delivery status notification in the
SMS::Send API. If a text message isn't immediately rejected by the provider
this plugin will report that the message was dispatched successfully. SMSNotify
can make no guarantees about whether the message was delivered. If you need
reliable, guaranteed-delivery messaging you should look elsewhere - but
remember that no message is truly received until a human has read and
acknowledged it.

=head1 INSTALLATION

Install RT::Extension::SMSNotify using CPAN or using the usual:

  perl Makefile.PL
  make
  sudo make install

process.

This extension can optionally install some scrip actions in your RT database.
If you do not install them, you can't create scrips via the RT web UI, but you
can still use C<RT::Action::SMSNotify> via C<rt-crontool> etc. You can add
scripactions manually if you prefer, or run:

  make initdb

as a user that has read permission to your C<RT_SiteConfig.pm>.  B<Do not run
C<make initdb> multiple times; this will result in duplicate entries in your RT
database>. If you have created duplicates you can carefully delete the
duplicates manually.  Alternately, delete all scrips that use the actions then
delete them all from your database's C<scripactions> table with something like:

    DELETE FROM scripactions WHERE name LIKE '[SMSNotify]%';

and add them back in by running C<make initdb> I<once>.

=head1 CONFIGURATION

 # Add the plugin to your RT_SiteConfig.pm's plugin list. (Append to any existing
 # @Plugins setting rather than adding a new one).
 Set(@Plugins, qw(RT::Extension::SMSNotify));

 # In RT_SiteConfig.pm, add entries for your SMS::Send provider and its setup
 # argument hash, eg:
 
 Set($SMSNotifyProvider, 'RedOxygen');
 Set($SMSNotifyArguments, {
 	_accountid  => 'XXXXXXXXXXX'
 	_email      => 'xxxxx@xxxxxxxxxxxxxxx',
 	_password   => 'xxxxxxxx'
 });
 
 # Then use RT-crontool to invoke the action or register it in the RT DB and use
 # it in scrips.

=head2 $SMSNotifyProvider

The C<$SMSNotifyProvider> parameter must be set to the name of an installed C<SMS::Send> module as a string, without the C<SMS::Send> qualifier. For example, to use L<SMS::Send::RedOxygen> you'd use:

  Set($SMSNotifyProvider, 'RedOxygen');

=head2 $SMSNotifyArguments

The C<$SMSNotifyArguments> parameter must be set to a hash reference with the
parameters the SMS:Send driver expects. The exact parameters will vary from
driver to driver. The sample given in L</"CONFIGURATION"> shows settings for
C<SMS::Send::RedSMS>.

=head2 $SMSNotifyGetPhoneForUserFn

A function reference. If defined, must be a function that takes an RT::User
as the 1st argument and returns a phone number as a string. The default implementation
looks up the RT::User's PagerPhone attribute, which is shown as Pager in the
RT UI, but you can replace this with an LDAP query or whatever you want.

Takes additional arguments of the Ticket being operated on or undef if no
ticket, and a user-defined hint extracted from the action argument if found as
documented in L<SMS::Action::SMSNotify>.

Return undef or the empty string if no phone number exists for a user. More
than one phone number may be returned by returning an array (not an arrayref);
all of them will be notified.

This method is useful for filtering users to limit the recipients of a message.

=head2 Use with rt-crontool

This is an example of RT::Extension::SMSNotify use with rt-crontool in
/etc/crontab format. The example presumes the existence of a template named
'SLA Alert SMS' and assumes that your local RT user is named 'requesttracker4'.
There must be a user in the RT database with 'gecos' set to the local RT user
Cron uses. The action argument specifies that notifications should be sent to
all ticket AdminCc users/groups and queue AdminCc watchers. Action arguments
are documented in L<RT::Action::SMSNotify>.

The search filter is a TicketSQL expression. You can use the RT query builder
to generate TicketSQL, but it's very limited so you will usually want to write
your own. You can test it by pasting it into the Advanced search in RT. This
search sends SMSes for any ticket with a due date set that's due 24-25 mins,
11-12 mins, or 3-5 mins from now. Since it runs every minute (C<*/1>; could
just be written as C<*>) this will generate one message for each of the first
time ranges and two for the 2nd.

The crontab entry:

  */1 * *   *   *   requesttracker4   rt-crontool --transaction last --search RT::Search::FromSQL --search-arg "(Status='new' OR Status='open') AND (Due > 'Jan 1, 1970') AND ((Due < '25 minutes' AND Due >= '24 minutes') OR (Due < '12 minutes' AND Due >= '11 minutes') OR (Due < '5 minutes' AND Due >= '3 minutes'))" --action RT::Action::SMSNotify --action-arg "TicketAdminCc,QueueAdminCc" --template 'SLA Alert SMS'

=head TEMPLATES

Unlike email templates, your SMS templates don't need a header. RT will
complain if you don't leave the first line blank in your template as it thinks
you still need headers.

Your template may use the following variables:

    Argument       The argument to this invocation of RT::Extension::SMSNotify
    TicketObj      The ticket object (undef if none) this action is acting on
    TransactionObj The current transaction
    PhoneNumber    The phone number this template invocation will be sent to
    UserObj        The RT::User whose pager number this is, or undef if it
                   was supplied by other means like the argument.

The template is executed once per SMS. If a user has more than one phone number
it'll be executed once per phone number so you'll see the same UserObj more
than once. Remember that UserObj can be C<undef>.

For example, a template for due date alerting could be:

  
  RT alert: {$Ticket->SubjectTag} is due in { $Ticket->DueObj->AgeAsString() }

=head1 LICENSE

The same as for Perl itself

=cut

use 5.10.1;
use strict;
use warnings;

BEGIN {
        our $VERSION = '1.00';
}

use RT::Action::SMSNotify;

1;
