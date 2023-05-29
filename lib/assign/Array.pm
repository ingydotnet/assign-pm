use strict; use warnings;
package assign::Array;

use assign::Struct;
use base 'assign::Struct';

use XXX;

sub parse_elem {
    my ($self) = @_;
    my $in = $self->{in};
    my $elems = $self->{elems};
    while (@$in) {
        my $tok = shift(@$in);
        my $type = ref($tok);
        next if $type eq 'PPI::Token::Whitespace';

        if ($type eq 'PPI::Token::Symbol') {
            my $str = $tok->content;
            if ($str =~ /^[\$\@]\w+$/) {
                my $elem = $self->get_var($str);
                push @$elems, $elem;
                return 1;
            }
        }

        # Parse @$a in the following if-statement.
        if ($type eq 'PPI::Token::Cast') {
            $tok->content eq '@' or
                XXX $tok, "unexpected token";
            $tok = shift(@$in);
            $type = ref($tok);
            my $str = $tok->content;
            $type eq 'PPI::Token::Symbol' and $str =~ /^\$\w+$/ or
                XXX $tok, "unexpected token";
            my $elem = $self->get_var($str);
            $elem->{cast} = 1;
            push @$elems, $elem;
            return 1;
        }

        if ($type eq 'PPI::Token::Number') {
            my $str = $tok->content;
            if ($str =~ /^[1-9][0-9]*$/) {
                push @$elems, skip_num->new($str);
                return 1;
            }
        }
        if ($type eq 'PPI::Token::Magic') {
            my $str = $tok->content;
            if ($str eq '_') {
                push @$elems, skip->new;
                return 1;
            }
            if ($str eq '$_') {
                push @$elems, var->new($str);
                return 1;
            }
        }
        XXX $tok, "unexpected token";
    }
    return 0;
}

sub gen_code {
    my ($self, $decl, $oper, $from, $init) = @_;

    my $code = [ @$init ];
    my $elems = $self->{elems};

    my $i = 0;
    for my $elem (@$elems) {
        my $type = ref $elem;
        my $dec = $decl;
        if ($type eq 'skip') {
            $i++;
            next;
        }
        if ($type eq 'skip_num') {
            $i += $elem->val;
            next;
        }
        if ($elem->val eq '$_') {
            $dec = '';
        }

        my $var = $elem->val;
        my $def = $elem->{def} // '';
        $def &&= " // $def";

        push @$code,
            ($elem->sigil eq '@')
                ? "$dec$var $oper \@$from\[$i..\@$from-1\]$def;" :
            ($elem->{cast})
                ? "$dec$var $oper \[\@$from\[$i..\@$from-1\]\]$def;" :
            "$dec$var $oper $from\->[$i]$def;";

        $i++;
    }

    return join "\n", @$code;
}

1;
