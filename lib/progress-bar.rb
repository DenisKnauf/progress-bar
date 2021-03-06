require 'dbus'

module ProgressBar
	def self.new *a
		if STDERR.tty?
			Console.new *a
		elsif 'KDE' == ENV['XDG_CURRENT_DESKTOP']
			KDialog.new *a
		else
			KDialog.new *a
		end
	end
end

class ProgressBar::Base
	attr_reader :max, :i, :text, :error
	attr_accessor :start
	def initialize max = nil, text = nil
		@start, @max, @i, @text, @error = Time.now, max || 100, 0, text || '', nil
		at_exit {finish}
	end

	def i= x
		@i = x.to_i
		change_progress
	end

	def max= val
		@max = val
		change_progress
	end

	def increment!( x = nil) self.i += (x || 1) end
	alias to_i i
	alias inc! increment!
	def done_rel() 100.0*i/max end
	def done_dur() Time.now-@start end

	def total_dur
		done_dur * max / i
	end

	def text= x
		@text = x
		change_text
	end

	def error= x
		@error = x
		change_error
	end

	def change_progress()  end
	def change_text()  end
	def change_error()  end
	def finish()  end
end

class ProgressBar::Console < ProgressBar::Base
	def initialize *a
		super *a
		change_text
	end

	def format_time t
		if t.finite?
			sprintf "%02d:%02d:%02d", t/3600, t/60 % 3600, t % 60
		else
			"--:--:--"
		end
	end

	def change_text
		l = [[100.0*i/max, 0].max, 100].min.to_i
		dd, td = done_dur, total_dur
		b = ?= * l
		b[-1] = ?>  unless 0 == l or 100 == l
		STDOUT.printf "\r\e[J%s / %s [%-*s] %s", format_time(dd), format_time(td), 100, b, text
	end
	alias change_progress change_text

	def change_error
		STDERR.printf "\r\e[J%s\n", error
		change_text
	end

	def finish
		STDERR.puts
	end
end

class ProgressBar::KDialog < ProgressBar::Base
	attr_reader :dialog_service_path, :dialog_object_path, :errors, :dialog_object
	def initialize max, text = nil, title = nil
		super max, text
		text = @text
		text = nil  if text.nil? or text.empty?
		title = nil  if title.nil? or title.empty?
		@errors = []
		args = ['kdialog', *(title ? ['--title', title] : []), '--progressbar', text || '.', max.to_s]
		@dialog_service_path, @dialog_object_path = IO.popen( args, 'r', &:readlines).join("\n").split ' '
		@dialog_bus = DBus.session_bus
		@dialog_service = @dialog_bus[@dialog_service_path]
		@dialog_object = @dialog_service.object @dialog_object_path
		@dialog_object.introspect
		@dialog_object.showCancelButton true
		change_text  if text.nil?
		change_progress
	rescue DBus::Error
		raise Interrupt  if $!.name == 'org.freedesktop.DBus.Error.ServiceUnknown'
		raise
	end

	def self.kdialog *a
		windowid = ENV['WINDOWID']
		windowid = (windowid.is_a?(String) && !windowid.empty?) ? ['--attach', windowid] : []
		system 'kdialog', *windowid, *a
	end
	def kdialog(*a)  self.class.kdialog *a  end

	def change_progress()
		@dialog_object.Set '', 'value', i
		raise Interrupt  if @dialog_object.wasCancelled.first
	rescue DBus::Error
		raise Interrupt  if $!.name == 'org.freedesktop.DBus.Error.ServiceUnknown'
		raise
	end

	def change_text()
		@dialog_object.setLabelText text
		raise Interrupt  if @dialog_object.wasCancelled.first
	rescue DBus::Error
		raise Interrupt  if $!.name == 'org.freedesktop.DBus.Error.ServiceUnknown'
		raise
	end

	def change_error()  @errors.push error  end
	def finish()
		@dialog_object.close rescue DBus::Error
		kdialog '--detailederror', "Some errors occured:", errors.join( "<br/>\n")  unless errors.empty?
	end

	def max= val
		@dialog_object.Set '', 'maximum', val
	end

	def max
		@dialog_object.Get '', 'maximum'
	end
end
