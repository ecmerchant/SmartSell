class Mylogger

  @queue = :resque_worker # queue名を指定

  def self.perform(x)
    logger.debug(x)
  end
  
end
