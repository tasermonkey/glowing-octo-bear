class Command
  def initialize(description, proc)
    @description = description
    @function =  proc
  end

  def execute
    @function.call unless @function.nil?
  end
end