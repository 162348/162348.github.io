// wpcf7awc v1.1

function wpcf7awc_count( field, counter, sp) {
	var htm = field.val();
	var space = sp;
	if ( htm == '' ) {
		counter.val('0');
		return;
	} // else

	// Add extra code 
	var regex = /\s+/gi;

	// if checked without space then value is true
	if(space == 'true') {
		var words = htm.trim().replace(regex, ' ').split(' ');
	} else {
		var words = htm.split(' ');	
	}
	// end extra code

	var num = words.length;
	var mx = field.data('maxawc');
	if(num > mx) {
		words = words.slice(0,mx);
		htm = '';
		for(w in words) {
			htm += words[w] + ' ';
		}
		field.val(htm);
		counter.val(mx);
	} else {
		if(space == 'true') {
			counter.val(htm.trim().replace(regex, ' ').split(' ').length);
		} else {
			counter.val(htm.split(' ').length);
		}
  	}
}

jQuery(function($) {
	$('form.wpcf7-form textarea[data-maxawc]').each(function() {
		var nam = $(this).attr('name');
		var space = $(this).attr('without-space');
		console.log(space);
		$(this).addClass('found').bind('input',function() {
			wpcf7awc_count($(this),$('#wcount_'+nam),space);
		}).trigger('input');
	});
});