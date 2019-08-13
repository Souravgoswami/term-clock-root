#!/usr/bin/ruby -w
%w(fileutils io/console).each(&method(:require))

Kernel.abort("Seems like your are running #{RUBY_ENGINE.capitalize} #{RUBY_VERSION}! Make sure you are using Ruby 2.5+...") if RUBY_VERSION.split(?.).first(2).join.to_i < 25

String.define_method(:colourize) do |cl = [63, 33, 39, 44, 49, 83, 118], cloning = true|
	col = cloning ? cl.dup.concat(cl.reverse) : cl
	colour_size, final_str = col.size - 1, ''

	each_line do |str|
		str_len = str.length
		div, index, i = str_len./(colour_size.next).then { |x| x < 1 ? 1 : x }, 0, -1

		while i < str_len
			index += 1 if ((i += 1).%(div).zero? && index < colour_size) && i > 1
			final_str.concat("\e[38;5;#{col[index]}m#{str[i]}")
		end
	end

	final_str + "\e[0m"
end

Kernel.abort "Uh oh! Cannot find a TTY! Please make sure you are running #{File.basename($0)} in a tty!".colourize unless STDOUT.tty?

Kernel.undef_method(:puts, :print)
Kernel.define_method(:puts) { |*str| STDOUT.puts(str.map { |x| x.is_a?(String) ? x.colourize : x.to_s.colourize }.join(?\n)) }
Kernel.define_method(:print) { |*str| STDOUT.print(str.map { |x| x.is_a?(String) ? x.colourize : x.to_s.colourize }.join) }
Kernel.class_exec { define_method(:then) { |&block| block.(self) } } unless defined?(Kernel.then)

def Animate(str = 'Please Wait...', &block)
	chars = %W(\xE2\xA0\x82 \xE2\xA0\x92 \xE2\xA0\xB2 \xE2\xA0\xB6 \xE2\xA0\xA2).map { |x| [x, x] }.flatten
	colours = [154, 184, 208, 203, 198, 164, 129, 92]
	t = Thread.new do
		loop do
			str.length.times { |i| STDOUT.print("\s#{chars.rotate![0]}\s#{str[0...i]}#{str[i].swapcase}#{str[i.next..-1]}\r".colourize(colours.rotate!(-1), false)) || sleep(0.05) }
			str.length.times { |i| STDOUT.print("\s#{chars.rotate![0]}\s#{str[i..-1]}#{str[0...i]}\r".colourize(colours.rotate!, false)) || sleep(0.05) }
		end
	end
	block.call(self).tap { t.kill }
end

def help
	b = File.basename($0)
	message = Kernel.system("sh -c 'type -p dpkg' > /dev/null") ? "\nFor [your] debian based system we suggest you to install the debian package for easy package management." : ''

	puts <<~EOF
		This is the term-clock installer.#{message}
		You can install / uninstall term-clock easily through this.

		Arguments:
			#{b} --help       Shows This help message
			#{b} --install    Downloads and moves term-clock to /
			#{b} --licence    Checks the licence of term-clock
			#{b} --uninstall  Uninstalls term-clock and all the files
			#{b} --version    Shows term-clock version
	EOF
end

def install
	require 'net/https'
	puts <<~EOF
		This is term-clock installer.
		#{'For Debian based systems, please consider installing the debian package for easier package management.' if Kernel.system("sh -c 'type -p dpkg > /dev/null'")}
	EOF

	file = File.join(__dir__, 'term-clock.rb')
	destination = File.join(%w(/ usr bin term-clock))

	puts('Press Y to download term-clock: ')
	return unless STDIN.getch.to_s.eql?(?y)
	begin
		File.write(file, Animate('Attempting to download term-clock from github. Please wait...') { Net::HTTP.get(URI('https://raw.githubusercontent.com/Souravgoswami/term-clock-root/master/term-clock.rb'))})
		puts "Saved data to #{file}"

		puts "Attempting to change the permission of #{file} to octal 755. Press Enter to confirm: "
		return unless STDIN.getch.to_s.eql?(?\r)
		File.chmod(0755, file)
		puts "Successfully changed the permission...\n\n"

		puts "Attepmpting to change the ownership and group of #{file} to 0. Press Enter to confirm: "
		return unless STDIN.getch.to_s.eql?(?\r)
		File.chown(0, 0, file)
		puts "Successfully changed the ownership and group to UID 0\n\n"

		puts "Attempting to move #{file} to #{destination}. Press Enter to confirm: "
		return unless STDIN.getch.to_s.eql?(?\r)
		FileUtils.mv(file, destination)
		puts "Successfully moved #{file} to #{destination}"

	rescue SocketError, OpenSSL::SSL::SSLError
		print 'Looks like you don\'t have an active internet connection :( Retry?(y/N): '
		retry if STDIN.gets.to_s.strip.downcase.eql?(?y)
	rescue Errno::EACCES
		Kernel.abort 'The downloaded data cannot be saved / moved. Reason: the folder has no write permission!'.colourize
	rescue Errno::EPERM
		Kernel.abort "Permission denied while trying to change the ownership of #{file}. Make sure you are root...".colourize
	rescue SignalException, Interrupt
		Kernel.abort 'The operation is terminated by the user.'.colourize
	rescue Exception => e
		Kernel.abort "Uh Oh! The installer just survived a crash! Reason:\n\n#{e.full_message}".colourize
	end
end

def uninstall
	puts <<~EOF
		This is term-clock uninstaller.
		#{'For Debian based systems, please consider using apt purge to uninstall this application if you have installed it via the debian package.' if Kernel.system("sh -c 'type -p dpkg > /dev/null'")}
	EOF

	Animate(" Press Y to uninstall term-clock...") { return unless STDIN.getch.to_s.eql?(?y) }

	%w(/usr/bin/term-clock /usr/share/term-clock/ /usr/share/doc/term-clock/).each do |x|
		if File.directory?(x)
			puts "Found Directory: #{x}.\nItems:\n#{Dir.children(x).map { |y| ?\t + y + ?\n }.join }"
			print "Delete directory #{x}? (Y/n): "
			puts("Skipping target #{x}") || next if STDIN.getch.to_s.eql?(?n)
			FileUtils.rm_rf(x)
			puts "Directory #{x} is not deleted. Probably you have no permission..." if Dir.exist?(x)

		elsif File.file?(x)
			print "Delete regular file: #{x}? (Y/n): "
			puts("Skipping target #{x}") || next if STDIN.getch.to_s.eql?(?n)

			begin
				File.delete(x)
			rescue Errno::EACCES
				puts "Regular file #{x} is not delete. You don't have necessary permission... Skipping target #{x}"
				next
			rescue Exception => e
				Kernel.abort "Uh Oh! The uninstaller just survived a crash! Reason:\n\n#{e.full_message}".colourize
			end
		end
	end
	puts
end

def version
	require 'net/https'
	if File.exist?('/usr/bin/term-clock')
		puts "Installed term-clock version: #{IO.readlines('/usr/bin/term-clock').detect { |x| x[/^VERSION.+$/] }.split(?\=)[1].to_s.delete(?')}"
	else
		puts "term-clock is not installed on your system. Run `#{$0} --install' to install term-clock."
	end

	begin
		puts "The latest version available on github is: #{Net::HTTP.get(URI('https://raw.githubusercontent.com/Souravgoswami/term-clock-root/master/term-clock.rb')).split(?\n).detect { |x| x[/^VERSION.+$/] }.split(?=)[-1].to_s.delete(?')}"
	rescue SocketError, OpenSSL::SSL::SSLError
	rescue Exception => e
		Kernel.abort "Uh Oh! The uninstaller just survived a crash! Reason:\n\n#{e.full_message}".colourize
	end
end

def licence
	STDOUT.puts <<~EOF.colourize([154, 184, 208, 203, 198, 164, 129, 92])
		MIT License

		Copyright (c) 2019 Sourav Goswami

		Permission is hereby granted, free of charge, to any person obtaining a copy
		of this software and associated documentation files (the "Software"), to deal
		in the Software without restriction, including without limitation the rights
		to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
		copies of the Software, and to permit persons to whom the Software is
		furnished to do so, subject to the following conditions:

		The above copyright notice and this permission notice shall be included in all
		copies or substantial portions of the Software.

		THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
		IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
		FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
		AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
		LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
		OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
		SOFTWARE.
	EOF
end


if ARGV.any? { |x| x[/^\-\-help$/] } || ARGV.empty? then help
elsif ARGV.any? { |x| x[/^\-\-licence$/] } then licence
elsif ARGV[0].to_s[/^\-\-install$/] then install
elsif ARGV[0].to_s[/^\-\-uninstall$/] then uninstall
elsif ARGV[0].to_s[/^\-\-version$/] then version
else
	puts <<~EOF
		Invalid argument #{ARGV[0]}
		Valid options are:
			(1) --help (2) --install (3) --licence
			(4) --uninstall (5) --version

		Note that #{File.basename($0)} can only accept
		one argument at a time.

		Please run `#{$0} --help' for additional help.
	EOF
end
