module Hobson::StonePacker

  # Hobson::StonePacker.pack(stones){|stone| stone.size }
  # Hobson::StonePacker.pack(stones, &:size)


  # Stone = Struct.new(:weight, :object)

  def self.pack stones, target_weight, &block
    block ||= :to_f.to_proc

    stones.sort_by!(&block).reverse!

    jars = []

    while stones.present?
      jar_weight = 0
      jar, stones = stones.partition {|stone|
        stone_weight = block.call(stone)
        jar_weight == 0 || jar_weight + stone_weight <= target_weight and jar_weight += stone_weight
      }
      jars << jar
    end

    return jars
  end

end
