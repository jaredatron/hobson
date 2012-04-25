require 'spec_helper'

describe Hobson::StonePacker do

  describe ".pack" do

    [
      [
        [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
        10,
        [[10], [9,1], [8,2], [7,3], [6,4], [5]],
      ],
      [
        [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
        7,
        [[10], [9], [8], [7], [6,1], [5,2], [4,3]],
      ],
      [
        [10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
        1,
        [[10], [9], [8], [7], [6], [5], [4], [3], [2], [1]],
      ],
      [
        [100, 10, 8, 8, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1],
        10,
        [[100], [10], [8, 1, 1], [8, 1, 1], [6, 4], [5, 5], [5, 5], [4, 4, 1, 1], [4, 4], [4]],
      ],
    ].each{|stones, size, expected|
      it { Hobson::StonePacker.pack(stones.shuffle, size).should == expected }
    }

    it "should take a block to call to get the weight of the given stones" do
      Hobson::StonePacker.pack([:xxxxx, :xxxx, :xxx, :xx, :x], 3, &:size).should == [[:xxxxx], [:xxxx], [:xxx], [:xx, :x]]
    end

  end

end
