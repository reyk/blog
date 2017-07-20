# Copyright (c) 2017 Reyk Floeter <contact@reykfloeter.com>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

.SUFFIXES: .xml .html .md

ARTICLEMDS	!= ls posts/*.md 
ARTICLES 	 = $(ARTICLEMDS:S/.md$/.html/g)
ARTICLEXMLS 	 = $(ARTICLEMDS:S/.md$/.xml/g)
ATOM 		 = atom.xml
HTMLS 		 = $(ARTICLES) index.html
TEMPLATEXMLS	 = templates/index.xml templates/article.xml templates/tags.xml
TEMPLATES	 = $(TEMPLATEXMLS:S/.xml$/.html/g)
TAGS		 = tags/index.html posts/tag-cloud.html

CLEANFILES	 = $(ATOM) $(ARTICLES) $(ARTICLEXMLS) $(HTMLS) $(TAGS)
CLEANFILES	+= $(ARTICLES:S/.html//) $(TEMPLATES) posts/tag-cloud*
CLEANFILES	+= tags/* *~ posts/*~ templates/*~ css/*~

all: $(HTMLS) $(ATOM) tags

install:
	# none

$(ARTICLES): $(ARTICLEXMLS) templates/article.html 

$(TEMPLATEXMLS): tags/index.html

index.html: templates/index.html $(ARTICLES) $(TAGS)
	sblg -o $@ -t templates/index.html $(ARTICLES)

atom.xml index.html $(ARTICLES) tags:

# Only include articles tagged with "blog" in the feed
# (it should be possible to filter this with sblg)
atom.xml: templates/atom.xml $(ARTICLES)
	BLOG=$$(grep -l "Tags:.*blog" $(ARTICLEMDS) | sed 's/\.md/.html/g'); \
	sblg -o $@ -t templates/atom.xml -a $${BLOG}

# Generate list of known tags...
tags/index.txt: $(ARTICLEXMLS)
	mkdir -p tags
	sblg -o- -rl $(ARTICLEXMLS) | awk '{ print $$1 }' | sort | uniq > $@

# ...and a simple HTML "tag cloud" for the menu...
tags/index.html: tags/index.txt
	{ (for i in $$(cat tags/index.txt); do \
		sblg -rl posts/*.xml | grep "^$$i" | wc -l | tr -d '\n'; \
		echo " $$i $$i"; \
	done) | sort -R | \
	xargs printf '<span class="tag-cloud tag-cloud-%d">\
		<a href="tags/%s">%s</a></span>\n'; } > $@

# ...and a page for each tag
tags: tags/index.txt templates/tags.html index.html
	for i in $$(cat tags/index.txt); do \
		sed "s/@NAVTAG@/$$i/g" templates/tags.html > tags/$$i.xml; \
		sblg -o tags/$$i.html -t tags/$$i.xml $(ARTICLES); \
		ln -sf $$i.html tags/$$i; \
	done

# ...and a fancy full-page tag cloud
posts/tag-cloud.html: $(TEMPLATES)
	sblg -o- -t templates/article.html templates/tag-cloud.xml | \
		sed -e '/@TAGS@/r tags/index.html' -e '/@TAGS@/d' > $@
	ln -sf tag-cloud.html posts/tag-cloud

$(TEMPLATEXMLS): templates/header.xml templates/footer.xml templates/navbar.xml

# Generate templates including a menu on the right side
# 1. Generate sidebar template from all articles
# 2. Mark sidebar nav as processed (data-sblg-nav="0")
# 3. Insert tag cloud
# 4. Insert sidebar into template
# 5. Insert other page elements (header, footer, navbar)
$(TEMPLATES): $(TEMPLATEXMLS) $(ARTICLESXMLS) templates/sidebar.xml
	sblg -o- -t templates/sidebar.xml $(ARTICLEXMLS) | \
	sed -e 's/data-sblg-nav="1"/data-sblg-nav="0"/g' \
		-e '/@TAGS@/r tags/index.html' -e '/@TAGS@/d' | \
	sed -e '/@SIDEBAR@/r /dev/stdin' -e '/@SIDEBAR@/d' \
	    -e '/@HEADER@/r templates/header.xml' -e '/@HEADER@/d' \
	    -e '/@FOOTER@/r templates/footer.xml' -e '/@FOOTER@/d' \
	    -e '/@NAVBAR@/r templates/navbar.xml' -e '/@NAVBAR@/d' \
	    -e '/@SOCIAL@/r templates/social.xml' -e '/@SOCIAL@/d' \
		$(@:S/.html/.xml/) > $@

.xml.html:
	sblg -o $@ -t templates/article.html -c $<
	ln -sf $(@:S/posts\///) $(@:S/.html//)

.md.xml: templates/social.xml
	TAGS=$$(lowdown -X Tags $< | tr -d '\t'); \
	TITLE=$$(lowdown -X Subject $< | tr -d '\t'); \
	AUTHOR=$$(lowdown -X From $< | tr -d '\t'); \
	DATE=$$(lowdown -X Date $< | tr -d '\t'); \
	{ echo "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>"; \
	  printf "<article data-sblg-article=\"1\" data-sblg-tags=\"%s\">\n\
		<header>\n\
		<h1><a href=\"%s\">%s</a></h1>\n\
	        <div>Posted by <address>%s</address> on <time datetime=\"%s\">%s</time></div>\n\
		</header>\n" "$$TAGS" "$(@:S/.xml//)" "$$TITLE" "$$AUTHOR" "$$DATE" "$$DATE"; \
	  lowdown $< ; \
	  cat templates/social.xml; \
	  echo "</article>"; } | \
	sed -e '2,/<p>/s/<p>/<aside><p>/g' -e '1,/<hr\/>/s/<hr\/>/<\/aside>/g' >$@

clean:
	rm -f $(CLEANFILES)

