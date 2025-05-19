require('./../lib/command_control')

DATA_DIRECTORY = './../www/data-U2lsZW5jZSBpcyBnb2xkZW4K'

c2_scripting = CommandControl::Scripting.new(DATA_DIRECTORY)
targets_list = c2_scripting.load_targets
pp(targets_list)
target_session = c2_scripting.load_target(targets_list[0]) unless targets_list.empty?
pp(target_session)
target_tree = c2_scripting.load_tree(target_session)
pp(target_tree)
