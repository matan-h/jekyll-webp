require 'open3'
require 'mkmf'

module Jekyll
  module Webp

    class WebpExec


      #
      # Runs the WebP executable for the given input parameters
      # the function detects the OS platform and architecture automatically
      #
      def self.run(quality, flags, input_file, output_file, webp_bin_fullpath,has_cwebp)
        if webp_bin_fullpath && webp_bin_fullpath!='nil' # in yml, "nil" is parsed as a string
          full_path = webp_bin_fullpath
        else
          if not has_cwebp
            Jekyll.logger.error "WebP:", "You need to install cwebp and make it available in the $PATH variable. (see https://developers.google.com/speed/webp/download. it called 'libwebp-tools' on fedora)"            
            exit(1)
          else
            full_path = 'cwebp'
          end
        end

        # Construct the full program call
        cmd = "\"#{full_path}\" -quiet -mt -q #{quality.to_s} #{flags} \"#{input_file}\" -o \"#{output_file}\""
        
        # Execute the command
        exit_code = 0
        error = ""
        output = ""
        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
          stdin.close # we don't pass any input to the process
          output = stdout.gets
          error = stderr.gets
          exit_code = wait_thr.value
        end

        if exit_code != 0
          Jekyll.logger.error("WebP:","Conversion for image #{input_file} failed, no webp version could be created for this image")
          Jekyll.logger.debug("WebP:","cwebp returned #{exit_code} with error #{error}")
        end

        # Return any captured return value
        return [output, error]
      end #function run


  end
end

end #module Jekyll
