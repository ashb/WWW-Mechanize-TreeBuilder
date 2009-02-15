package WWW::Mechanize::TreeBuilder;

=head1 NAME

WWW::Mechanize::TreeBuilder

=head1 SYNOPSIS

 use Test::More tests => 2;
 use Test::WWW::Mechanize;
 # or 
 # use WWW::Mechanize;
 # or 
 # use Test::WWW::Mechanize::Catalyst 'MyApp';

 my $mech = WWW::Mechanize->new;
 # or
 #my $mech = Test::WWW::Mechanize::Catalyst->new;
 # etc. etc.
 WWW::Mechanize::TreeBuilder->meta->apply($mech);

 $mech->get_ok('/');
 ok( $mech->look_down(_tag => 'p')->as_trimmed_text, 'Some text', 'It worked' );

=head1 DESCRIPTION

This module combines WWW::Mechanize and HTML::TreeBuilder. Why? Because I've 
seen too much code like the following:

 like($mech->content, qr{<p>some text</p>}, "Found the right tag");

Which is just all flavours of wrong - its akin to processing XML with regexps.
Instead, do it like the following:

 ok($mech->look_down(_tag => 'p', sub { $_[0]->as_trimmed_text eq 'some text' })

The anon-sub there is a bit icky, but this means that if the p tag should 
happen to add attributes to the C<< <p> >> tag (such as an id or a class) it
will still work and find the right tag.

All of the methods avaiable on L<HTML::Element> (that aren't 'private' - i.e. 
everything that doesn't begin with an underscore) such as C<look_down> or 
C<find> are automatically delegated to C<< $mech->tree >> through the magic of
Moose.

=head1 METHODS

Everything in L<WWW::Mechanize> (or which ever sub class you apply it to) and
all public methods from L<HTML::Element> except those which WWW::Mechanize
and HTML::Element give this method. In the case where WWW::Mechanize and 
HTML::TreeBuilder boht define a method, the one from WWW::Mechanize will be 
used (so that the behaviour of Mechanize wont get broken.)

=cut

use Moose::Role;
use HTML::TreeBuilder;

our $VERSION = '1.00003';

requires '_make_request';

has 'tree' => ( 
  is        => 'ro', 
  isa       => 'HTML::Element',
  writer    => '_set_tree',
  predicate => 'has_tree',
  clearer   => 'clear_tree',
  default   => undef,

  # Since HTML::Element isn't a moose object, i have to 'list' everything I 
  # want it to handle myself here. how annoying. But since I'm lazy, I'll just
  # take all subs from the symbol table that dont start with a _
  handles => sub {
    my ($attr, $delegate_class) = @_;

    $DB::single = 1;
    my %methods = map { $_->name => 1 
      } $attr->associated_class->get_all_methods,
        $attr->associated_class->get_all_attributes;

    return 
      map  { $_->name => $_->name }
      grep { my $n = $_->name; $n !~ /^_/ && !$methods{$n} } $delegate_class->get_all_methods; 
  }
);

around '_make_request' => sub {
  my $orig = shift;
  my $self = shift;
  my $ret  = $self->$orig(@_);

  # Someone needs to learn about weak refs
  if ($self->has_tree) {
    $self->tree->delete;
    $self->clear_tree;
  }

  if ($ret->content_type =~ m[^(text/html|application/(?:.*?\+)xml)]) {
    $self->_set_tree( HTML::TreeBuilder->new_from_content($ret->decoded_content)->elementify );
  } 
  
  return $ret;
};

sub DEMOLISH {
  my $self = shift;
  $self->tree->delete if $self->has_tree;
}

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >>

=head1 LICENSE

Same as Perl 5.8, or at your option any later version of Perl.

=cut

1;
