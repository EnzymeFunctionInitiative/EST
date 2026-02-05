=pod

=head3 add

=over 4

=item Summary

Add two numbers and return the result

=item Parameters

=over 4

=item C<a> (I<int>)

the first number

=item C<b> (I<int>)

the second number

=back

=item Returns

The sum of C<a> and C<b>

=back
=cut
sub add {
    $a, $b = @_;
    $c = $a + $b;
    return $c;
}

if ($ARGV[0] eq "--help") {
    print "usage text\n";
}