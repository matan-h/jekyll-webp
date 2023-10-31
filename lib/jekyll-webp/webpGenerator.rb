require "jekyll/document"
require "fileutils"

def progress_bar(percent, max = 100, file = "", max_file_len = 20)
  # round_to100 = 100/max
  # puts round_to100
  # percent*=round_to100
  # percent=org_percent*round_to100
  # Calculate the number of bars to display.
  bars = (percent * (max / 2)).round
  if not file.empty?
    file = "[#{file}]"
  end

  # Print the progress bar.
  mimic_logger = "              WebP:"
  print "\r#{mimic_logger}[#{("=" * bars)}#{(" " * ([(max / 2) - bars, 0].max))}] #{(percent * 100).round}% #{file}#{" " * max_file_len}#{"\b" * max_file_len}"
  # print Jekyll.logger.message("WebP:", "\r[#{('=' * bars)}#{(' ' * ([(max/2) - bars,0].max))}] #{(percent*100).round}% #{file}#{' ' * max_file_len}#{"\b" * max_file_len}")
end

module Jekyll
  module Webp

    #
    # A static file to hold the generated webp image after generation
    # so that Jekyll will copy it into the site output directory
    class WebpFile < StaticFile
      def write(dest)
        true # Recover from strange exception when starting server without --auto
      end
    end #class WebpFile

    class WebpGenerator < Generator
      # This generator is safe from arbitrary code execution.
      safe true

      # This generator should be passive with regard to its execution
      priority :lowest

      # Generate paginated pages if necessary (Default entry point)
      # site - The Site.
      #
      # Returns nothing.
      def generate(site)

        # Retrieve and merge the configuration from the site yml file
        @config = DEFAULT.merge(site.config["webp"] || {})

        # If disabled then simply quit
        if !@config["enabled"]
          Jekyll.logger.info "WebP:", "Disabled in site.config."
          return
        end

        Jekyll.logger.debug "WebP:", "Starting"

        # If the site destination directory has not yet been created then create it now. Otherwise, we cannot write our file there.
        Dir::mkdir(site.dest) if !File.directory? site.dest

        # If nesting is enabled, get all the nested directories too
        if @config["nested"]
          newdir = []
          for imgdir in @config["img_dir"]
            # Get every directory below (and including) imgdir, recursively
            newdir.concat(Dir.glob(imgdir + "/**/"))
          end
          @config["img_dir"] = newdir
        end

        # Counting the number of files generated
        file_count = 0
        has_cwebp = find_executable("cwebp")

        # Iterate through every image in each of the image folders and create a webp image
        # if one has not been created already for that image.
        for imgdir in @config["img_dir"]
          imgdir_source = File.join(site.source, imgdir)
          imgdir_destination = File.join(site.dest, imgdir)
          FileUtils::mkdir_p(imgdir_destination)
          Jekyll.logger.info "WebP:", "Processing #{imgdir_source}"
          # handle only jpg, jpeg, png and gif
          dir = Dir[imgdir_source + "**/*.*"]
          progress_max = dir.length.to_f
          max_file_len = (dir.max_by { |x| x.length }).length
          min_file_len = (dir.min_by { |x| x.length }).length
          max_space_len = max_file_len - min_file_len
          is_progressbar = false
          # progress_bar(0,progress_max,'',0) # init progress-bar

          for i in (0...dir.length)
            imgfile = dir[i]
            imgfile_relative_path = File.dirname(imgfile.sub(imgdir_source, ""))

            # TODO: Do an exclude check
            # Create the output file path
            file_ext = File.extname(imgfile).downcase
            outfile_filename = if @config["append_ext"]
                File.basename(imgfile) + ".webp"
              else
                file_noext = File.basename(imgfile, file_ext)
                file_noext + ".webp"
              end
            # puts "i:#{i}\tprogress_max:#{progress_max}\tbars:#{(i/progress_max * 50).round}"
            # If the file is not one of the supported formats, exit early
            next if !@config["formats"].include? file_ext

            FileUtils::mkdir_p(imgdir_destination + imgfile_relative_path)
            outfile_fullpath_webp = File.join(imgdir_destination + imgfile_relative_path, outfile_filename)

            # Check if the file already has a webp alternative?
            # If we're force rebuilding all webp files then ignore the check
            # also check the modified time on the files to ensure that the webp file
            # is newer than the source file, if not then regenerate
            if @config["regenerate"] || !File.file?(outfile_fullpath_webp) ||
               File.mtime(outfile_fullpath_webp) <= File.mtime(imgfile)
              # Jekyll.logger.info "WebP:", "Change to source image file #{imgfile} detected, regenerating WebP"

              # Generate the file
              WebpExec.run(@config["quality"], @config["flags"], imgfile, outfile_fullpath_webp, @config["webp_path"], has_cwebp)
              file_count += 1
              progress_bar(i / progress_max, progress_max, outfile_filename, max_space_len); is_progressbar = true
            end
            if File.file?(outfile_fullpath_webp)
              # Keep the webp file from being cleaned by Jekyll
              site.static_files << WebpFile.new(site,
                                                site.dest,
                                                File.join(imgdir, imgfile_relative_path),
                                                outfile_filename)
            end
          end # dir.foreach
          if (is_progressbar)
            progress_bar(1, progress_max, "", max_space_len)
            print "\n"
          end
        end # img_dir

        Jekyll.logger.info "WebP:", "Generator Complete: #{file_count} file(s) generated"
      end #function generate
    end #class WebPGenerator
  end #module Webp
end #module Jekyll
