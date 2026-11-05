
import argparse




def add_args(parser: argparse.ArgumentParser):
    parser.add_argument("--input", required=True, type=str, help="The raw SSN input file")
    parser.add_argument("--output", required=True, type=str, help="The sanitized SSN output file")


def create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Sanitize SSN files (remove unsupported characters from XGMML files and return UTF-8-encoded file)")
    add_args(parser)
    return parser


def sanitize_xml(input_path: str, output_path: str):
    """
    Processes a SSN file line-by-line, removing unsupported characters and ensuring the output
    file is UTF-8 encoded.  Rather than doing a full parse, a regex is used to replace invalid
    characters in each line.

    Parameters
    ----------
        input_path
            path to the input raw SSN file
        output_path
            path to the output sanitized SSN file
    """

    with open(input_path, 'rb') as infile, open(output_path, 'wb') as outfile:
        # Read first line to fix encoding declaration if present
        first_line = infile.readline()
        if b'<?xml' in first_line:
            # Replace whatever encoding="..." declaration with encoding="UTF-8"
            import re
            first_line = re.sub(b'encoding=["\'][^"\']*["\']', b'encoding="UTF-8"', first_line, flags=re.IGNORECASE)

        # Strip out non-ASCII/invalid bytes (0x80 to 0xFF) in the declaration line
        outfile.write(first_line.translate(bytes.maketrans(b'', b''), bytes(range(0x80, 0x100))))

        for line in infile:
            # Replace non-ASCII byte range characters (0x80 - 0xFF) with spaces
            clean_line = line.translate(bytes.maketrans(bytes(range(0x80, 0x100)), b' ' * 128))
            outfile.write(clean_line)


if __name__ == '__main__':
    args = create_parser().parse_args()

    sanitize_xml(args.input, args.output)
