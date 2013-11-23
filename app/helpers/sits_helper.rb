module SitsHelper
	def teaser(sit, length = 300)
		truncate(strip_tags(sit.custom_strip), :length => length, :omission => " ...")
	end 

	def teaser_title(sit, type = false) 
		if sit.s_type == 0
      title = "#{link_to "#{sit.duration} minutes", sit, :class => 'sit-link'}".html_safe
			title.insert(0, " sat for ") if !type 
		elsif sit.s_type == 1
			title = "#{link_to "#{sit.title}", sit, :class => 'sit-link'}".html_safe
			title.insert(0, " added a new diary: ") if !type
		else
			" added a new article: #{link_to "#{sit.title}", sit, :class => 'sit-link'}".html_safe
		end
		return title
	end

	def previous_sit(sit)
		if sit.prev(current_user).nil?
			"<li class='previous'><div class=\"disabled\" title=\"This is the first entry\">&larr; Previous</div></li>".html_safe
		else
			"<li class='previous'><a href=\"#{sit_path(@sit.prev(current_user))}\">&larr; Previous</a></li>".html_safe
		end
	end

	def next_sit(sit)
		if sit.next(current_user).nil?
    	"<li class='next'><div class=\"disabled\" title=\"This is the latest entry\">Next &rarr;</div></li>".html_safe
    else
      "<li class='next'><a href=\"#{sit_path(@sit.next(current_user))}\">Next &rarr;</a></li>".html_safe
		end
	end

	def display_lock_if_private(sit)
		if sit.private
			'<div class="private-event pull-right" title="This is a private entry. Only you can see it."><i class="fa fa-lock"></i></div>'.html_safe
		end
	end
end
