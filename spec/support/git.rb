class Git < Pathname

  attr_reader :url
  def initialize path, url
    super(path)
    @url = url
  end

  def clone!
    return if exist?
    sh <<-SH
      cd "#{parent}" && git clone "#{url}" "#{basename}"
    SH
  end

  def inspect
    "#<Git:#{@url}@#{@path}"
  end

  private

  def sh cmd
    output = `#{cmd}` or raise "failed to run #{cmd.inspect}"
  end

end
