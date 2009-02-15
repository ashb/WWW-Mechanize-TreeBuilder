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

The anon-sub there is a bit icky, but this means that anyone should happen to
add attributes to the C<< <p> >> tag (such as an id or a class) it will still
work and find the right tag.

All of the methods avaiable on L<HTML::Element> (that aren't 'private' - i.e. 
that don't begin with an underscore) such as C<look_down> or C<find> are
automatically delegated to C<< $mech->tree >> through the magic of Moose.

=head1 METHODS

Everything in L<WWW::Mechanize> (or which ever sub class you apply it to) and
all public methods from L<HTML::Element> except those where WWW::Mechanize
and HTML::Element overlap. In the case where WWW::Mechanize and
HTML::TreeBuilder both define a method, the one from WWW::Mechanize will be
used (so that the existing behaviour of Mechanize doesn't break.)

=cut

use MooseX::Role::Parameterized;
use Moose::Util::TypeConstraints;
#use HTML::TreeBuilder;

subtype 'WWW.Mechanize.TreeBuilder.TreeClass'
  => as 'ClassType',
  => where { Class::MOP::load_class($_) && $_->isa('HTML::TreeBuilder') };

subtype 'WWW.Mechanize.TreeBuilder.ElementClass'
  => as 'ClassType',
  => where { Class::MOP::load_class($_) && $_->isa('HTML::Element') };

our $VERSION = '1.00004';

parameter tree_class => (
  isa => 'WWW.Mechanize.TreeBuilder.TreeClass',
  required => 1,
  default => 'HTML::TreeBuilder',
);

parameter element_class => (
  isa => 'WWW.Mechanize.TreeBuilder.ElementClass',
  lazy => 1,
  default => 'HTML::Element',
  predicate => 'has_element_class'
);

# Used if element_class is not provided to give sane defaults
our %ELEMENT_CLASS_MAPPING = (
  'HTML::TreeBuilder' => 'HTML::Element',
  # HTML::TreeBuilder::XPath does it wrong.
  'HTML::TreeBuilder::XPath' => 'HTML::TreeBuilder::XPath::Node'
);

role {
  my $p = shift;

  my $tree_class = $p->tree_class;
  my $ele_class;
  unless ($p->has_element_class) {
    $ele_class = $ELEMENT_CLASS_MAPPING{$tree_class};

    if (!defined( $ele_class ) ) {
      local $Carp::Internal{'MooseX::Role::Parameterized::Meta::Role::Parameterizable'} = 1;
      Carp::carp "WWW::Mechanize::TreeBuilder element_class not specified for overridden tree_class of $tree_class";
      $ele_class = "HTML::Element";
    }

  } else {
    $ele_class = $p->element_class;
  }

requires '_make_request';

has 'tree' => ( 
  is        => 'ro', 
  isa       => $ele_class,
  writer    => '_set_tree',
  predicate => 'has_tree',
  clearer   => 'clear_tree',
  default   => undef,

  # Since HTML::Element isn't a moose object, i have to 'list' everything I 
  # want it to handle myself here. how annoying. But since I'm lazy, I'll just
  # take all subs from the symbol table that dont start with a _
  handles => sub {
    my ($attr, $delegate_class) = @_;
    #$delegate_class = Moose::Meta::Class->initialize($p->tree_class);

    $DB::single = 1;
    my %methods = map { $_->name => 1 
      } $attr->associated_class->get_all_methods;

    return 
      map  { $_->name => $_->name }
      grep { my $n = $_->name; $n !~ /^_/ && !$methods{$n} } 
        $delegate_class->get_all_methods;
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
    $self->_set_tree( $tree_class->new_from_content($ret->decoded_content)->elementify );
  } 
  
  return $ret;
};

sub DEMOLISH {
  my $self = shift;
  $self->tree->delete if $self->has_tree;
}

};

no MooseX::Role::Parameterized;

=head1 AUTHOR

Ash Berlin C<< <ash@cpan.org> >>

=head1 LICENSE

Same as Perl 5.8, or at your option any later version of Perl.

=cut

1;
