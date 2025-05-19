require('./lib/command_control')

DATA_DIRECTORY = './www/data-U2lsZW5jZSBpcyBnb2xkZW4K'

c2_cli = CommandControl::CLI.new(DATA_DIRECTORY)
c2_cli.show_targets
c2_cli.show_actions
