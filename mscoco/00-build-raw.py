import os
import json
import argparse


def main(params):
  val = json.load(open(params['val_file'], 'r'))
  train = json.load(open(params['train_file'], 'r'))

  # combine all images and annotations together
  imgs = val['images'] + train['images']
  annots = val['annotations'] + train['annotations']

  # for efficiency lets group annotations by image
  itoa = {}
  for a in annots:
      imgid = a['image_id']
      if not imgid in itoa: itoa[imgid] = []
      itoa[imgid].append(a)

  # create the json blob
  out = []
  for i,img in enumerate(imgs):
      imgid = img['id']
      
      # coco specific here, they store train/val images separately
      loc = 'train2014' if 'train' in img['file_name'] else 'val2014'
      
      jimg = {}
      jimg['file_path'] = os.path.join(loc, img['file_name'])
      jimg['id'] = imgid
      
      sents = []
      annotsi = itoa[imgid]
      for a in annotsi:
          sents.append(a['caption'])
      jimg['captions'] = sents
      out.append(jimg)
      
  json.dump(out, open(params['output_json'], 'w'))

if __name__ == "__main__":

  parser = argparse.ArgumentParser()

  # input json
  parser.add_argument('--val_file', required=True, help='input json file of val images')
  parser.add_argument('--train_file', required=True, help='input json file of train images')
  parser.add_argument('--output_json', default='coco_raw.json', help='output json file')

  args = parser.parse_args()
  params = vars(args) # convert to ordinary dict
  print 'parsed input parameters:'
  print json.dumps(params, indent = 2)
  main(params)
