#!/usr/bin/env ruby

require 'json'

Region = Struct.new(:x1, :y1, :x2, :y2)

def region_area(region)
  w = region.x2 - region.x1
  h = region.y2 - region.y1
  w * h
end

def region_intersection(r1, r2)
  dx = [r1.x2, r2.x2].max - [r1.x1, r2.x1].min
  dy = [r1.y2, r2.y2].max - [r1.y1, r2.y1].min
  return dx * dy if dx >= 0 && dy >= 0
end

def regions_overlap?(r1, r2)
  !region_intersection(r1, r2).nil?
end

def parse_estimated_bibs(json_file)
  JSON.parse(File.read(json_file))['bib']['regions'].map do |r|
    region = Region.new
    region.x1 = r['x1']
    region.y1 = r['y1']
    region.x2 = r['x2']
    region.y2 = r['y2']
    region
  end
end


def union_of_regions(r1, r2)
  region = Region.new
  region.x1 = [r1.x1, r2.x1].min
  region.y1 = [r1.x1, r2.y1].min
  region.x2 = [r1.x1 + r1.x2, r2.x1 + r2.x2].max
  region.y2 = [r1.y1 + r1.y2, r2.y1 + r2.y2].max
  region
end

def intersection_of_regions(r1, r2)
  region = Region.new
  region.x1 = [r1.x1, r2.x1].max
  region.y1 = [r1.x1, r2.y1].max
  region.x2 = [r1.x1 + r1.x2, r2.x1 + r2.x2].min
  region.y2 = [r1.y1 + r1.y2, r2.y1 + r2.y2].min
  w = region.x2 - region.x1
  h = region.y2 - region.y1
  return nil if w < 0 || h < 0
  region
end

def mp_score(r1, r2)
  min_bounding_box = union_of_regions(r1, r2)
  intersection_box = intersection_of_regions(r1, r2)
  return 0 if intersection_box.nil?
  puts "R1", r1
  puts "R2", r2
  puts "MB", min_bounding_box
  puts "IB", intersection_box
  puts "==="
  intersection_box_area = region_area(intersection_box)
  min_bounding_box_area = region_area(min_bounding_box)
  intersection_box_area.to_f / min_bounding_box_area.to_f
end

def best_match(r, set_of_rects)
  set_of_rects.map { |r_prime| mp_score(r, r_prime) }.max
end

def precision(ground_truths, estimated_bibs)
  best_estimates = estimated_bibs.map { |r_e| best_match(r_e, ground_truths) }
  sum_of_estimates = best_estimates.reduce(:+)
  sum_of_estimates / estimated_bibs.count
end

def recall(ground_truths, estimated_bibs)
  best_estimates = ground_truths.map { |r_t| best_match(r_t, estimated_bibs) }
  sum_of_estimates = best_estimates.reduce(:+)
  sum_of_estimates / ground_truths.count
end

def f_score(precision, recall, alpha = 0.5)
  1 / ((alpha / precision) + ((1 - alpha) / recall))
end

def parse_ground_truth_bibs(json_file)
  JSON.parse(File.read(json_file))['TaggedRunners'].map do |runner|
    region = Region.new
    j = 0
    rdict = runner['Bib']['PixelPoints'].each_with_index.map do |coords_str, i|
      # Only want 0,2 (two extremes)
      next unless (i % 2).zero?
      j += 1
      x, y = coords_str.split(', ')
      [["x#{j}", x.to_i], ["y#{j}", y.to_i]]
    end
    rdict = Hash[*rdict.compact.flatten]
    region.x1 = rdict['x1']
    region.y1 = rdict['y1']
    region.x2 = rdict['x2']
    region.y2 = rdict['y2']
    region
  end
end

def main()
  ground_truth_json = ARGV[0]
  estimated_bib_json = ARGV[1]

  raise 'No ground truth JSON file provided' if ground_truth_json.nil?
  raise 'No bib detect JSON file provided' if estimated_bib_json.nil?

  ground_truths = parse_ground_truth_bibs(ground_truth_json)
  estimated_bibs = parse_estimated_bibs(estimated_bib_json)

  p = precision(ground_truths, estimated_bibs)
  r = recall(ground_truths, estimated_bibs)
  f = f_score(p, r)

  puts "#{p},#{r},#{f}"
end

main
